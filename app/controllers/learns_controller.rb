require 'rexml/document'
require 'net/http'

class LearnsController < ApplicationController
	model :ent_module
	model :ent_seq
	model :operation_log

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
		
		@bodystr_html = ""
		#node_array = GetXTDLNodeIDs(view_mod[:module_name].to_s)
		@bodystr_html = GetXTDLSources(@learn.contents)
	end
	
	def GetXTDLSources(node_id)
		str_buff = ""
		
		http = Net::HTTP.new('localhost',8080)
		
		#req = Net::HTTP::Get.new("/exist/rest/db/adel_v2/xtdl_resources/#{resource_name}.xml?_query=//*[@id=%22#{node_id}%22]")
		req = Net::HTTP::Get.new("/exist/rest/db/adel_v3/xtdl_resources/list.xml?_query=//*[@id=%22#{node_id}%22]")
		res = http.request(req)

		# DOM を生成
		doc = REXML::Document.new res.body
		doc = doc.elements["//*[@id='#{node_id}']"]
		str_buff += XTDLNodeSearch(doc)
		
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
end