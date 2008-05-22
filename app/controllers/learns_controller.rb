require 'rexml/document'
require 'net/http'

class LearnsController < ApplicationController
  # GET /learns
  # GET /learns.xml
  def index
    @learns = Learn.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @learns }
    end
  end

  # GET /learns/1
  # GET /learns/1.xml
  #def show
  #  @learn = Learn.find(params[:id])

  #  respond_to do |format|
  #    format.html # show.html.erb
  #    format.xml  { render :xml => @learn }
  #  end
  #end

  # GET /learns/new
  # GET /learns/new.xml
  def new
    @learn = Learn.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @learn }
    end
  end

  # GET /learns/1/edit
  def edit
    @learn = Learn.find(params[:id])
  end

  # POST /learns
  # POST /learns.xml
  def create
    @learn = Learn.new(params[:learn])

    respond_to do |format|
      if @learn.save
        flash[:notice] = 'Learn was successfully created.'
        format.html { redirect_to(@learn) }
        format.xml  { render :xml => @learn, :status => :created, :location => @learn }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @learn.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /learns/1
  # PUT /learns/1.xml
  def update
    @learn = Learn.find(params[:id])

    respond_to do |format|
      if @learn.update_attributes(params[:learn])
        flash[:notice] = 'Learn was successfully updated.'
        format.html { redirect_to(@learn) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @learn.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /learns/1
  # DELETE /learns/1.xml
  def destroy
    @learn = Learn.find(params[:id])
    @learn.destroy

    respond_to do |format|
      format.html { redirect_to(learns_url) }
      format.xml  { head :ok }
    end
  end
  
	def next
		operation_event("next","-")
	end
	
	def show
		@learn = Learn.find(params[:id])
		#makeView(@learn.contents)
		redirect_to :action => "view", :id => @learn.contents
	end
	
	def view
		if(params[:id])
			makeView(params[:id])
		else
			makeView(ModuleLog.getCurrentModule(session[:user].id , SeqLog.getCurrentId(session[:user].id) ))
		end
	end
	
	def makeView(mod_id)
		view_mod = EntModule.find(:first,:conditions=>"id = #{mod_id}")
		
		@bodystr_html = ""
		node_array = GetXTDLNodeIDs(view_mod[:module_name].to_s)
		@bodystr_html = GetXTDLSources(node_array)
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
=begin
    elsif dom_obj.name["examination"] then ## テスト記述要素ならば
      # テストフラグをON
      $test_flag = true
      
      # テスト記述要素以下をすべてテスト機構にPost
      http = Net::HTTP.new('localhost' , 80)
      req = Net::HTTP::Post.new("/~learn/cgi-bin/prot_test/adel_exam.cgi")
      res = http.request(req,"&mode=set&user_id=#{session[:user].id}&src=" + dom_obj.to_s)
      str_buff += res.body

      testid = dom_obj.attributes["id"]

      str_buff += "<br /><br /><form method=\"post\" action=\"/adel_v2/public/learning/examCommit?testname=#{testid}\" class=\"button-to\"><div><input type=\"submit\" value=\"テストの合否判定\" /></div></form>"
=end
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
		#cur_level = LevelLog.getCurrentLevel(session[:user].id , SeqLog.getCurrentId(session[:user].id) )
		cur_level = 1	# とりあえず1で固定
		
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
=begin
		#ログインユーザのインスタンスを取得
		user = User.find(session[:user].id)
		cur_seq_id = SeqLog.getCurrentId(user[:id])
		
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
		#redirect_to :action=>'view', :dis=>ope_log[:dis_code]
		redirect_to :action=>'view'
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
=begin
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
=end
			when /false/          # 実行するアクション無し
			end
		end
	end

end