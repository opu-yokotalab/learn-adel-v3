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
				# XML-DB ����w���XTDL���\�[�X���擾
				req = Net::HTTP::Get.new("/exist/rest/db/adel_v3/xtdl_resources/#{resource_name}.xml?_query=//*[@id=%22#{node_id}%22]")
				res = http.request(req)
				
				# DOM �𐶐�
				doc = REXML::Document.new res.body
				doc = doc.elements["//*[@id='#{node_id}']"]
				
				if(doc)
					str_buff += XTDLNodeSearch(doc)
				end
			end
		end
		
		return str_buff
	end

	# �ċA�I�Ƀm�[�h��T��
	def XTDLNodeSearch(dom_obj)
	# �Ӗ��v�f�@�z��
		semantic_elem_array = ["explanation","example","illustration","definition","program","algorithm","proof","simulation"]

		str_buff = ""
		flag = false # ����t���O
		if dom_obj.name["section"] ## section �v�f�Ȃ��
			if dom_obj.attributes["title"] != ""
				str_buff += "<h2>" + dom_obj.attributes["title"].toutf8 + "</h2>"
			else
				str_buff += "<br /><br />"
			end
			dom_obj.each_element do |elem|
				str_buff += XTDLNodeSearch(elem)
			end
=begin
    elsif dom_obj.name["examination"] then ## �e�X�g�L�q�v�f�Ȃ��
      # �e�X�g�t���O��ON
      $test_flag = true
      
      # �e�X�g�L�q�v�f�ȉ������ׂăe�X�g�@�\��Post
      http = Net::HTTP.new('localhost' , 80)
      req = Net::HTTP::Post.new("/~learn/cgi-bin/prot_test/adel_exam.cgi")
      res = http.request(req,"&mode=set&user_id=#{session[:user].id}&src=" + dom_obj.to_s)
      str_buff += res.body

      testid = dom_obj.attributes["id"]

      str_buff += "<br /><br /><form method=\"post\" action=\"/adel_v2/public/learning/examCommit?testname=#{testid}\" class=\"button-to\"><div><input type=\"submit\" value=\"�e�X�g�̍��۔���\" /></div></form>"
=end
		else ## �Ӗ��v�f�@�Ȃ��
			if dom_obj.attributes["title"] != ""
				str_buff += "<h3>" + dom_obj.attributes["title"].toutf8 + "</h3>"
			else
				str_buff += "<br /><br />"
			end
			# �q��HTML�H�Ӗ��v�f�H
			semantic_elem_array.each do |semantic_elem|
				if dom_obj.elements["./#{semantic_elem}"]
					flag = true
				end
			end
			
			if flag
				# �Ӗ��v�f�̏ꍇ
				dom_obj.each_element do |elem|
					str += XTDLNodeSearch(elem)
				end
			else
				# HTML�̏ꍇ
				dom_obj.each do |elem|
					str_buff += elem.to_s.toutf8
				end
			end
		end
		
		return str_buff
	end
	
	def GetXTDLNodeIDs(ent_module_name)
		# �w�K��DB���狳�ރ��W���[���@���擾
		ent_mod = EntModule.find(:first,:conditions=>"module_name = '#{ent_module_name}'")
		#���W���[�������refs���o
		doc = REXML::Document.new ent_mod[:module_src]
		doc = doc.elements["/module"]
		# node_array [ [ resource_name , [res_id,...]], ... ]
		node_array = []
		# ���݊w�K���̊w�K�V�[�P���V���OID���擾
		# ���݂̊w�K�҃��x�����擾
		#cur_level = LevelLog.getCurrentLevel(session[:user].id , SeqLog.getCurrentId(session[:user].id) )
		cur_level = 1	# �Ƃ肠����1�ŌŒ�
		
		# �񎦂��ׂ�ID���擾
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
		#���O�C�����[�U�̃C���X�^���X���擾
		user = User.find(session[:user].id)
		cur_seq_id = SeqLog.getCurrentId(user[:id])
		
		#����R�[�h�}���O�Ɏ��Ԃ��L�^
		time_log = RuleSearchTimeLog.new
		time_log[:user_id] = user[:id]
		time_log[:time_name] = 'before_perl'
		time_log[:time_value] = Time.now
		time_log.save
=end
		ope_log = OperationLog.new
		# ����R�[�h ���O�ɋL�^)
		ope_log[:operation_code] = ope_code
		# ���쎯�ʃR�[�h�@�ݒ�
		ope_log[:dis_code] = Time.now.to_i
		# Event�����@�ݒ�
		ope_log[:event_arg] = e_arg
		# �e�[�u���Ԃ̊֘A�t��
		ope_log[:ent_seq_id] = cur_seq_id
		ope_log[:user_id] = user[:id]
		
		OperationLog.transaction do
			ope_log.save!
			
			# Action ���s
			if action_array_obj = getActionCode(ope_log)
				execAction(user,action_array_obj)
			else
				flash[:notice]="�A�N�V�����R�[�h�̎擾�Ɏ��s���܂����B"
			end
		end
=begin
		#Action�����Ɏ��Ԃ��L�^
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
		#�A�N�V�������s
		action_array_obj.each do |action_obj|
			case action_obj[:action_code]
			when /view/           # ���ރ��W���[����
				
				# ���O��ǉ�
				mod_log = ModuleLog.new
				
				if /end/ =~ action_obj[:action_value]
					mod_log[:ent_module_id] = -1
				else
					ent_mod = EntModule.find(:first,:conditions=>"module_name = '#{action_obj[:action_value]}'")
					mod_log[:ent_module_id] = ent_mod[:id]
				end
				
				# �V�[�P���V���O�Ɗw�K�҂�ID���֘A�t����
				cur_seq = SeqLog.getCurrentId(user[:id])
				mod_log[:ent_seq_id] = cur_seq
				mod_log[:user_id] = user[:id]
				# �ۑ�
				mod_log.save!
				
				# ���̂��Ƃ�Action�̓X�L�b�v����
				return
=begin
      when /retryall/       # �S�̂��Ċw�K
        # SEQ�̐擪ID���擾
        # ModuleLog �ɒǉ�
      when /exit/           # �w�K�̏I��
        mod_log = ModuleLog.new
        mod_log[:ent_module_id]=-1
        mod_log[:ent_seq_id] =cur_seq
        mod_log[:user_id] = user[:id]
        mod_log.save!
        
        return        
      when /changeLv/       # �w�K�҃��x���̕ύX
        lev_log = LevelLog.new
        cur_seq = SeqLog.getCurrentId(user[:id])

        # �V�[�P���V���O�Ɗw�K�҂�ID���֘A�t����
        lev_log[:level] = action_obj[:action_value]
        lev_log[:ent_seq_id] = cur_seq
        lev_log[:user_id] = user[:id]
        #�ۑ�
        lev_log.save!
      when /assist/
=end
			when /false/          # ���s����A�N�V��������
			end
		end
	end

end