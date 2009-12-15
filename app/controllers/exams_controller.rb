class ExamsController < ApplicationController
	#テスト機構：プレ評価
	def exam_pre_evaluate
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

		## ダミー解答
		# 受け取った解答情報を処理
		#params["selected"] = "q4_0_0" # 正解
		#params["selected"] = "q4_0_1" # 不正解

		#params["type"] = "radio" # 単一選択式問題
		#params["type"] = "checked" # 複数選択
		#params["value"] = "value" # テキスト入力

		#params["value"] = "0" # 選んだ選択肢
		#params["value"] = "1"
		#params["value"] = "2"

		# あるテストで出題された問題の固有識別子
		#params["ques_pkey"] = "f2ad3984f7e59f93863af5bf577303bb"

		## 本処理
		# 評価モジュールのインスタンス生成
		evalQues = Evaluate.new

		# 評価結果格納用のハッシュ
		evalResultHash = Hash.new

		# 出題テーブルから出題履歴を作成
		# テストの固有識別子を作成
		# 履歴モジュールのインスタンス作成
		setHis = History.new

		# 履歴DBに接続
		#conn = setHis.open_setHistory(base_pgsql_host, base_pgsql_port, pgsql_user_name, pgsql_user_passwd)

		# 出題履歴
		setHisHash = Hash.new
		setHisHash = setHis.get_setHistory(params[:ques_pkey])

		# プレ評価
		evalResultHash = evalQues.preEvaluate(params[:type], params[:ques_pkey], params[:value], setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
		#p evalResultHash
		# 評価履歴を記録
		setHis.put_preEvalHistory(params[:ques_pkey], evalResultHash)

		# 履歴DBから切断
		#setHis.close_setHistory(conn)

		# ブラウザで表示させるためのおまじない
		#print "Content-type: text/html\n\n"
		#print "<e_result>" + evalResultHash["eval_result"]  + "</e_result>"
		@bodystr_html = "<e_result>" + evalResultHash["eval_result"]  + "</e_result>"
	end
	
	def exam_evaluate # テストの評価
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

		# プレ評価で得点は出してるのでまとめるだけ…なはず
		# ques_pkeyと各グループid、問題idで一番新しい物だけを取得
		# 正解、不正解のxhtmlを返して、評価履歴のcomp_evalをtrueにする

		# ダミー
		#params["ques_pkey"] = "7529c20403cba45d9f5caa751a6af921"
		#params["name"] = "q4_0"

		# 履歴モジュールのインスタンスを作成
		evalHis = History.new

		# 指定無しで出題機構のインスタンスを生成(履歴は作らない)
		setQues = Set_question.new("eval_mode")

		# 履歴格納用のハッシュ
		setHisHash = Hash.new
		evalHisHash = Hash.new

		# 履歴DBに接続
		#conn = evalHis.open_setHistory(base_pgsql_host, base_pgsql_port, pgsql_user_name, pgsql_user_passwd)

		# 評価モジュールのインスタンス生成
		# 解答確定に評価機構は要らない？
		evalQues = Evaluate.new

		# ques_pkeyからプレ評価履歴を取得
		evalHisHash = evalHis.get_preEvalHistory(params[:ques_pkey])

		# 解答履歴が無かった場合
		# 未解答マークを付けて解答ログに記録?
		#p evalHisHash.size
		if evalHisHash.size == 0 then
			# 出題履歴
			setHisHash = Hash.new
			setHisHash = evalHis.get_setHistory(params[:ques_pkey])
			#p setHisHash
			# 未解答の場合に、未解答のログをつける
			evalResultHash = Hash.new
			evalResultHash = evalQues.preEvaluate("radio", "NULL", "NULL", setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
			#p evalResultHash
			# 評価履歴を記録
			evalHis.put_preEvalHistory(params[:ques_pkey], evalResultHash)

			# 再度ques_pkeyからプレ評価履歴を取得
			evalHisHash = evalHis.get_preEvalHistory(params[:ques_pkey])
		end

		# 確定した解答にマークをつける
		evalHis.put_evalHistory(evalHisHash["evaluate_pkey"])

		# 評価結果に応じたxhtmlを生成
		# ques_pkeyから出題履歴を取得
		setHisHash = evalHis.get_setHistory(params[:ques_pkey])

		# 履歴DBから切断
		#evalHis.close_setHistory(conn)

		# 出題履歴から簡易的な出題テーブルを作成
		tblAry = Array.new
		tmpSetHash = {"group_id" => setHisHash["group_id"], "mark" => setHisHash["group_mark"], "item_id" => setHisHash["ques_id"], "ques_pass" => setHisHash["ques_pass"],"ques_type" => setHisHash["ques_id"] , "selection_type" => "", "ques_correct" => "", "time" => "", "test_key" => ""}
		tblAry << tmpSetHash

		# 出題テーブルから中間xmlを作成
		setElem = REXML::Element.new
		setElem = setQues.make_xml(tblAry, base_eXist_host, base_eXist_port, base_db_uri, base_inputType_uri)

		# 必要な部分木を取り出しxhtmlを生成
		xhtmlElem = REXML::Element.new
		#puts setElem
		xhtmlElem = setQues.make_xhtml(setElem.elements["//item"], base_eXist_host, base_eXist_port, base_xslt_eval_uri)

		# 提示に必要な情報を付け加える
		xpath_str = "/div[@id=\"item_" + setHisHash["group_id"] + "_" + setHisHash["ques_id"] + "\"]/div[@id=\"title_" + setHisHash["group_id"] + "_" + setHisHash["ques_id"] + "\"]/h2"
		if evalHisHash["eval_result"].to_i  >= evalHisHash["total_point"].to_i then # 問題の点数に満たないとき不正解
			xhtmlElem.elements[xpath_str].add_text("正解!")
		else
			xhtmlElem.elements[xpath_str].add_text("不正解...")
		end
		#$stderr.print xhtmlElem.to_s + "\n"

		# 選んだ選択肢の装飾（赤太字） ちょっと動かない。あとで原因究明
		#  xpath_str = "/div[@id=\"item_" + setHisHash["group_id"] + "_" + setHisHash["ques_id"] + "\"]/div[@id=\"response_" + setHisHash["group_id"] + "_" + setHisHash["ques_id"] + "\"]/ul/li[@id=\"" + setHisHash["ques_id"] + "\"]/"
		#$stderr.print xpath_str + "\n"
		#  xhtmlElem.elements[xpath_str].add_attribute("style", "{ color:red; font-weight:bolder }")

		# ブラウザで表示させるためのおまじない
		#print "Content-type: text/html\n\n"
		#print xhtmlElem
		@bodystr_html = xhtmlElem
	end
end
