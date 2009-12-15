require 'rexml/document'
require 'net/http'

require 'func/set_questions'
require 'func/history'
require 'func/evaluate'

class LearnsController < ApplicationController
	skip_before_filter :verify_authenticity_token
	
	def nextModule
		operation_event("next","-")
	end
	
	def toc
		operation_event("toc",params[:id])
	end
	
	def changeLv
		operation_event("changeLv",params[:id])
	end
	
	def show
		user = User.find(session[:user])
		#学習シーケンシングログを更新：Update SEQID
		seqlog = SeqLog.new
		seqlog[:ent_seq_id] = params[:id]
		user.seq_log << seqlog
		
		unless seqlog.save
			flash[:notice] = "SEQ Log テーブルの更新に失敗"
			return
		end
		
		#next redirect(Query To Rule Engine)
		cur_mod_id = ModuleLog.getCurrentModule(session[:user], SeqLog.getCurrentId(session[:user]))
		
		if(cur_mod_id == -1)
			redirect_to :action => 'nextModule'
		else
			redirect_to :action => 'view', :id=>'-1'
		end
	end
	
	def examCommit
		# test_key_hashをテスト機構に問合せ
		#http = Net::HTTP.new('localhost',80)
		#req = Net::HTTP::Post.new("/~learn/cgi-bin/prot_test_v3/adel_exam.cgi")
		#req = Net::HTTP::Post.new("/cgi-bin/prot_test/adel_exam.cgi")
		#res = http.request(req,"&mode=get_testkey&user_id=#{session[:user]}")
		#test_key_hash = res.body
		test_key_hash = exam_get_testkey(session[:user])
		
		# テスト結果を取得
		#http = Net::HTTP.new('localhost' , 80)
		#req = Net::HTTP::Get.new("/~learn/cgi-bin/prot_test_v3/adel_exam.cgi?mode=result&test_key=#{test_key_hash}")
		#req = Net::HTTP::Get.new("/cgi-bin/prot_test/adel_exam.cgi?mode=result&test_key=#{test_key_hash}")
		#res = http.request(req)
		res = exam_result(test_key_hash)
		res_buff = res.split(/,/)
		
		#result [["q_id","得点"], ... ]
		result = []
		res_buff.each do |t|
			result.push t.split(/:/)
		end
		
		#テストIDを取得
		test_name = params[:id]
		testID = EntTest.find(:first,:conditions=>"test_name = '#{test_name}'")
		#現在のシーケンシングIDとモジュールIDを取得
		seqID = SeqLog.getCurrentId(session[:user])
		moduleID = ModuleLog.getCurrentModule(session[:user], seqID)
		
		sum = 0  # 合計点
		result.each do |q|
			#問題IDを取得
			qID = EntQuestion.find(:first,:conditions=>"question_name = '#{q[0]}'")
			qlog = QuestionLog.new
			qlog[:user_id] = session[:user]
			qlog[:ent_seq_id] = seqID
			qlog[:ent_module_id] = moduleID
			qlog[:ent_test_id] = testID[:id]
			qlog[:ent_question_id] = qID[:id]
			qlog[:point] = q[1].to_i
			#問題グループ毎のログを保存
			QuestionLog.transaction do
				qlog.save!
			end
			
			# テスト結果の合計点を計算
			sum += q[1].to_i
		end
		
		# テスト結果の合計点をログに保存
		testlog = TestLog.new
		testlog[:user_id] = session[:user]
		testlog[:ent_seq_id] = seqID
		testlog[:ent_module_id] = moduleID
		testlog[:ent_test_id] = testID[:id]
		testlog[:sum_point] = sum
		
		# ログ作成
		TestLog.transaction do
			testlog.save!
		end
		
		# nextリダイレクト
		redirect_to :action => 'nextModule'
	end
	
	def view
		@user = User.find(:first, :conditions=>"id = #{session[:user]}")
		dis_code = params[:id]

		# 提示メッセージの検索,リストに格納
		@msg = Array.new
		msg_action = ActionLog.find(:all,:conditions=>"action_code = 'msg' AND dis_code = #{dis_code}",:order=>"id")
		msg_action.each do |m|
			@msg.push(m[:action_value].gsub(/\"/,'').toutf8)
		end
		
		@cur_level = LevelLog.getCurrentLevel(session[:user], SeqLog.getCurrentId(session[:user]))
		
		makeView(ModuleLog.getCurrentModule(session[:user], SeqLog.getCurrentId(session[:user])))
	end
	
	def makeView(mod_id)
		view_mod = EntModule.find(:first, :conditions=>"id = #{mod_id}")
		if view_mod
			@bodystr_html = ""
			node_array = GetXTDLNodeIDs(view_mod[:module_name].to_s)
			@bodystr_html = GetXTDLSources(node_array)
		else
			@bodystr_html = "<h2>学習を終了します.</h2>"
			
			@seqList=[]
			i=0
			if session[:user]
				seqs = EntSeq.find(:all,:order=>"id")
				seqs.each do |seq|
					@seqList[i] = [seq.id,seq.seq_title.toutf8]
					i+=1
				end
			end
		end
		
		# 目次項目提示プロセス
		seq_id = SeqLog.getCurrentId(session[:user])
		if seq_id != -1
			ent_seq = EntSeq.find(seq_id)
			# buffList: [[mod_id , xtdl_id] , ........]
			nextList = []
			tocList = []
			buffList = []
			seq_src = ent_seq[:seq_src].gsub(/(\s|\n)/,'').split(/\./)
			i =0
			while i < seq_src.length
				# tocのモジュールIDを抽出
				if /toc\((.+?),.*\)/ =~ seq_src[i]
					tocList.push($1)
				end
				# nextのモジュールIDを抽出
				if /next\(\[(.+?),(.+?)\],.*\)/ =~ seq_src[i]
					mod = [$1,$2]
					if mod[0] != "start"
						nextList.push(mod[0])
					end
					if mod[1] != "end"
						nextList.push(mod[1])
					end
				end
				i+=1
			end
			# 重複要素を削除
			nextList.uniq!
			tocList.uniq!
			# 参照しているリソースの最初のtitle属性の値を抽出
			nextList.each do |m|
				# node_array [ [ resource_name , [res_id,...]], ... ]
				node_array = GetXTDLNodeIDs(m)
				buffList << [m , node_array[0], tocList.include?(m)]
			end
			#tocList: [[mod_id , title name , true|false] , ........]
			@tocList = []
			# リソースからタイトル属性の値を抜く
			buffList.each do |buff|
				@tocList << [buff[0] , GetElementTitle(buff[1]), buff[2]]
			end
		end
	end
	
	def GetElementTitle(node_res_ids)
		http = Net::HTTP.new('localhost',8080)
		resource_name = node_res_ids[0]
		node_id = node_res_ids[1][0]
		# XML-DB から指定のXTDLリソースを取得
		req = Net::HTTP::Get.new("/exist/rest/db/adel_v3/xtdl_resources/#{resource_name}.xml?_query=//*[@id=%22#{node_id}%22]")
		res = http.request(req)
		
		doc = REXML::Document.new res.body
		elem = doc.elements["//*[@id='#{node_id}']"]
		if elem == nil
			return node_id
		else
			title = elem.attributes["title"]
			if title != ""
				return title
			else
				return "no title"
			end
		end
	end
	
	def GetXTDLSources(node_id_array)
		str_buff = ""
		
		http = Net::HTTP.new('localhost',8080)
		
		node_id_array.each do |node_res_ids|
			resource_name = node_res_ids[0]
			node_res_ids[1].each do |node_id|
				# XML-DB から指定のXTDLリソースを取得
				req = Net::HTTP::Get.new("/exist/rest/db/adel_v3/xtdl_resources/#{resource_name}.xml?_query=//*[@id=%22#{node_id}%22]")
				res = http.request(req)
				
				# DOM を生成
				doc = REXML::Document.new res.body
				doc = doc.elements["//*[@id='#{node_id}']"]
				
				if(doc)
					str_buff += XTDLNodeSearch(doc)
				end
			end
		end
		
		return str_buff
	end

	# 再帰的にノードを探索
	def XTDLNodeSearch(dom_obj)
	# 意味要素　配列
		semantic_elem_array = ["explanation","example","illustration","definition","program","algorithm","proof","simulation"]
		
		str_buff = ""
		flag = false # 判定フラグ
		if dom_obj.name["section"] ## section 要素ならば
			if dom_obj.attributes["title"] != ""
				str_buff += "<h2>" + dom_obj.attributes["title"].toutf8 + "</h2>"
			else
				str_buff += "<br /><br />"
			end
			dom_obj.each_element do |elem|
				str_buff += XTDLNodeSearch(elem)
			end
		elsif dom_obj.name["examination"] then ## テスト記述要素ならば
			# テストフラグをON
			@test_flag = true
			
			# テスト記述要素以下をすべてテスト機構にPost
			#http = Net::HTTP.new('localhost', 80)
			#http = Net::HTTP.new('localhost', 4000)
			#req = Net::HTTP::Post.new("/~learn/cgi-bin/prot_test_v3/adel_exam.cgi")
			#req = Net::HTTP::Post.new("/cgi-bin/prot_test/adel_exam.cgi")
			#req = Net::HTTP::Post.new("/")
			#res = http.request(req,"&mode=set&user_id=#{session[:user]}&src=" + dom_obj.to_s)
			
			str_buff += exam_set(session[:user],dom_obj.to_s)
			
			#str_buff += res.body
			
			testid = dom_obj.attributes["id"]
			
			str_buff += "<br /><br /><form method=\"POST\" action=\"/examCommit/#{testid}\" class=\"button-to\"><div><input type=\"submit\" value=\"テストの合否判定\" /></div></form>"
		else ## 意味要素　ならば
			if dom_obj.attributes["title"] != ""
				str_buff += "<h3>" + dom_obj.attributes["title"].toutf8 + "</h3>"
			else
				str_buff += "<br /><br />"
			end
			# 子はHTML？意味要素？
			semantic_elem_array.each do |semantic_elem|
				if dom_obj.elements["./#{semantic_elem}"]
					flag = true
				end
			end
			
			if flag
				# 意味要素の場合
				dom_obj.each_element do |elem|
					str += XTDLNodeSearch(elem)
				end
			else
				# HTMLの場合
				dom_obj.each do |elem|
					str_buff += elem.to_s.toutf8
				end
			end
		end
		
		return str_buff
	end
	
	def GetXTDLNodeIDs(ent_module_name)
		# 学習者DBから教材モジュール　を取得
		ent_mod = EntModule.find(:first,:conditions=>"module_name = '#{ent_module_name}'")
		#モジュールからのrefs抽出
		doc = REXML::Document.new ent_mod[:module_src]
		doc = doc.elements["/module"]
		# node_array [ [ resource_name , [res_id,...]], ... ]
		node_array = []
		# 現在学習中の学習シーケンシングIDを取得
		# 現在の学習者レベルを取得
		cur_level = LevelLog.getCurrentLevel(session[:user], SeqLog.getCurrentId(session[:user]) )
		
		# 提示すべきIDを取得
		doc.each_element { |elem_block|
			elem_block.each_element { |elem_node|
				level_array = elem_node.attributes["level"].split(/,/)
				level_array.each do |level|
					if /#{cur_level}|\*/ =~ level
						node_array.push [ elem_node.attributes["resource"], elem_node.attributes["refs"].split(/,/)]
						break
					end
				end
			}
		}
		return node_array
	end
	
	def operation_event(ope_code,e_arg)
		#ログインユーザのインスタンスを取得
		user = User.find(session[:user])
		cur_seq_id = SeqLog.getCurrentId(user[:id])
=begin
		#操作コード挿入前に時間を記録
		time_log = RuleSearchTimeLog.new
		time_log[:user_id] = user[:id]
		time_log[:time_name] = 'before_perl'
		time_log[:time_value] = Time.now
		time_log.save
=end
		
		ope_log = OperationLog.new
		# 操作コード ログに記録)
		ope_log[:operation_code] = ope_code
		# 操作識別コード　設定
		ope_log[:dis_code] = Time.now.to_i
		# Event引数　設定
		ope_log[:event_arg] = e_arg
		# テーブル間の関連付け
		ope_log[:ent_seq_id] = cur_seq_id
		ope_log[:user_id] = user[:id]
		
		OperationLog.transaction do
			#ECAルールの実行ログを取る，ルールを評価
			ope_log.save!
			
			# Action 実行
			if action_array_obj = getActionCode(ope_log)
				execAction(user,action_array_obj)
			else
				flash[:notice]="アクションコードの取得に失敗しました。"
			end
		end
=begin
		#Action決定後に時間を記録
		time_log = RuleSearchTimeLog.new
		time_log[:user_id] = user[:id]
		time_log[:time_name] = 'after_perl'
		time_log[:time_value] = Time.now
		time_log.save
=end
		redirect_to :action=>'view', :id=>ope_log[:dis_code]
	end
	
	def getActionCode(table_obj)
		where = "user_id = :user_id AND dis_code = :dis_code"
		value = {:user_id =>"#{session[:user]}", :dis_code => "#{table_obj.dis_code}"}
		# アクションコード取得失敗 -> 最大5秒間待つ
		for i in 1..10
			sleep 0.5
			if action_array_obj = ActionLog.find(:all,:conditions=>[where,value],:order=>"id")
				return action_array_obj
			else
				next
			end
		end
		
		return nil
	end
	
	def execAction(user,action_array_obj)
		#アクション実行
		action_array_obj.each do |action_obj|
			case action_obj[:action_code]
			when /view/           # 教材モジュール提示
				
				# ログを追加
				mod_log = ModuleLog.new
				
				if /end/ =~ action_obj[:action_value]
					mod_log[:ent_module_id] = -1
				else
					ent_mod = EntModule.find(:first,:conditions=>"module_name = '#{action_obj[:action_value]}'")
					mod_log[:ent_module_id] = ent_mod[:id]
				end
				
				# シーケンシングと学習者のIDを関連付ける
				cur_seq = SeqLog.getCurrentId(user[:id])
				mod_log[:ent_seq_id] = cur_seq
				mod_log[:user_id] = user[:id]
				# 保存
				mod_log.save!
				
				# そのあとのActionはスキップする
				return
			when /retryall/       # 全体を再学習
				# SEQの先頭IDを取得
				# ModuleLog に追加
			when /exit/           # 学習の終了
				mod_log = ModuleLog.new
				mod_log[:ent_module_id]=-1
				mod_log[:ent_seq_id] =cur_seq
				mod_log[:user_id] = user[:id]
				mod_log.save!
				
				return
			when /changeLv/       # 学習者レベルの変更
				lev_log = LevelLog.new
				cur_seq = SeqLog.getCurrentId(user[:id])
				
				# シーケンシングと学習者のIDを関連付ける
				lev_log[:level] = action_obj[:action_value]
				lev_log[:ent_seq_id] = cur_seq
				lev_log[:user_id] = user[:id]
				#保存
				lev_log.save!
			when /assist/
			when /false/          # 実行するアクション無し
			end
		end
	end
	
	#テスト機構：出題
	def exam_set(user_id,src)
		# eXist, postgreSQLの接続先のホスト
		base_eXist_host = 'localhost'
		# eXist用接続ポート
		base_eXist_port = 8080
		# 問題DB
		base_db_uri = "/exist/rest/db/adel_v3/examination/db/"

		# XSLTスタイルシート
		base_xslt_all_uri = "/exist/rest/db/adel_v3/examination/test.xsl"
		base_xslt_eval_uri = "/exist/rest/db/adel_v3/examination/evaluate.xsl"

		# XHTML変換時に問題形式からinput要素のtype属性値
		# を決定するための変換テーブル
		base_inputType_uri = "/exist/rest/db/adel_v3/examination/input_type.xml"

		# エラー時に表示するxhtml
		base_err_uri = "/exist/rest/db/adel_v3/examination/error.xml"

		# Webサーバからドキュメントを取得
		#http = Net::HTTP.new(base_eXist_host, base_eXist_port)
		#req = Net::HTTP::Get.new(base_call_uri)
		
		#res = http.request(req)
		
		# ダミーの呼び出し記述
		#params["src"] = res.body
		
		## 本処理  
		# DOMオブジェクトに変換
		tmpDoc = REXML::Document.new(src)
		
		# ユーザid取得
		#user_id = params["user_id"].to_s
		# ユーザidを指定して、出題機構のインスタンスを生成
		setQues = Set_question.new(user_id)
		
		# 呼び出し記述から出題テーブルを生成
		setTable = Array.new
		setTable = setQues.make_table(tmpDoc, base_eXist_host, base_eXist_port, base_db_uri)
		
		# 出題テーブルから出題履歴を作成
		# テストの固有識別子を作成
		setHis = History.new
		
		# 履歴DBに接続
		#conn = setHis.open_setHistory(base_pgsql_host, base_pgsql_port, pgsql_user_name, pgsql_user_passwd)
		
		# テーブルの要素ごとに処理
		setTable.each do |tblLine|
			# 1ラインずつ履歴を記録
			setHis.put_setHistory(user_id, setQues.get_testId, tblLine)
		end
		
		# 履歴DBから切断
		#setHis.close_setHistory(conn)
		
		# 出題テーブルから中間XMLを生成
		setElem = REXML::Element.new
		setElem = setQues.make_xml(setTable, base_eXist_host, base_eXist_port, base_db_uri, base_inputType_uri)
		
		# 中間XMLをXSLTを用いてXHTMLに変換
		xhtmlElem = REXML::Element.new
		xhtmlElem = setQues.make_xhtml(setElem, base_eXist_host, base_eXist_port, base_xslt_all_uri)
		
		# ブラウザで表示させるためのおまじない
		#print "Content-type: text/html\n\n"
		# print xhtmlElem.to_s # 動作確認用（完全なxhtmlを出力）
		return xhtmlElem.get_elements("//body/node()").to_s
	end
	
	def exam_get_testkey(user_id) # 作成したテストの固有識別子(一度の出題限り有効)
		# 受け取ったユーザidの一番新しい出題のtest_keyを渡せばいいんじゃないかと。

		# ダミー
		#params["user_id"] = "uid"

		# 履歴モジュールのインスタンスを作成
		testHis = History.new

		# 履歴DBに接続
		#conn = testHis.open_setHistory(base_pgsql_host, base_pgsql_port, pgsql_user_name, pgsql_user_passwd)

		# 指定されたuser_idをもつ最新のtest_keyを返す
		str = testHis.get_testidByUserid(user_id)

		# 履歴DBから切断
		#testHis.close_setHistory(conn)

		# ブラウザで表示させるためのおまじない
		#print "Content-type: text/html\n\n"
		#print "<test_key>" + str + "</test_key>"
		return str
	end
	
	def exam_result(test_key) # テスト全体の評価結果出力
		# 正規化した評価結果を渡す
		# {"group_id" => 得点(配点*得点率), ...}
		# 得点率 = グループ単位で獲得した得点/グループから出題された問題の総得点

		#params["test_key"] = "6a0027335cdc26cbd4a0ec5f13c0f4b7"

		# 履歴モジュールのインスタンスを作成
		evalHis = History.new

		# 評価モジュールのインスタンスを生成
		evalQues = Evaluate.new

		# 履歴格納用のハッシュ
		evalHisHash = Hash.new

		# 履歴DBに接続
		#conn = evalHis.open_setHistory(base_pgsql_host, base_pgsql_port, pgsql_user_name, pgsql_user_passwd)

		# テスト全体の評価に必要な情報を取得
		tblEval = evalHis.get_evalHistory(test_key)
		#p tblEval  

		# 評価結果に未評価部分がある
		reEvalFlag = 0 # 再評価のフラグ
		tblEval.each{|tblLine|
			if tblLine["eval_result"] == "" then
				# 未回答状態でプレ評価
				# 出題履歴
				setHisHash = Hash.new
				setHisHash = evalHis.get_setHistory(tblLine["eval_key"].to_s)
				#p setHisHash
				# 未解答の場合に、未解答のログをつける
				evalResultHash = Hash.new
				evalResultHash = evalQues.preEvaluate("radio", "NULL", "NULL", setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
				#p evalResultHash
				# 評価履歴を記録
				evalHis.put_preEvalHistory(tblLine["eval_key"].to_s, evalResultHash)      

				# ques_pkeyからプレ評価履歴を取得
				evalHisHash = evalHis.get_preEvalHistory(tblLine["eval_key"].to_s)

				# 確定した解答にマークをつける
				evalHis.put_evalHistory(evalHisHash["evaluate_pkey"].to_s)

				# 再評価を行う
				reEvalFlag = 1
		end
		}

		if reEvalFlag == 1 then # 再評価が必要
			# 再度テスト全体の評価に必要な情報を取得
			tblEval = evalHis.get_evalHistory(test_key)
			#p tblEval
			# フラグの初期化
			reEvalFlag = 0
		end

		# 履歴DBから切断
		#evalHis.close_setHistory(conn)

		# 評価結果の正規化
		normHash = Hash.new
		normHash = evalQues.evaluate(tblEval)

		# ハッシュを受け渡すための形式に変換
		str = String.new
		normHash.each{|key, value|
			str = str + key.to_s + ":" + value.to_s + ","
		}
		str = str.slice(0, str.size - 1)

		# ブラウザで表示させるためのおまじない
		#print "Content-type: text/html\n\n"
		#print "<result>" + str + "</result>"
		return str
	end
end