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
  
	def show
		@learn = Learn.find(params[:id])
		view_mod = EntModule.find(:first,:conditions=>"id = #{@learn.contents}")
		
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
		
=begin
		#req = Net::HTTP::Get.new("/exist/rest/db/adel_v2/xtdl_resources/#{resource_name}.xml?_query=//*[@id=%22#{node_id}%22]")
		req = Net::HTTP::Get.new("/exist/rest/db/adel_v3/xtdl_resources/list.xml?_query=//*[@id=%22#{node_id}%22]")
		res = http.request(req)
		
		# DOM を生成
		doc = REXML::Document.new res.body
		doc = doc.elements["//*[@id='#{node_id}']"]
		str_buff += XTDLNodeSearch(doc)
=end
		
		#str_buff = res.body
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

end