class OperationLog < ActiveRecord::Base
	belongs_to :ent_seq
	after_save :rule_evaluate

	def rule_evaluate
		# �C�x���g�擾
		ope_code = self[:operation_code]
		# SEQ���O���猻�݂�ECA���[�����擾
		ent_seq = EntSeq.find(self[:ent_seq_id])
		seq_src = ent_seq[:seq_src]
		# �󔒂Ɖ��s�̍폜�@���@.�ŕ���
		seq_src = seq_src.gsub(/(\s|\n)/,'').split(/\./)

		# EcaRuleMatrix�̍쐬
		seq_mat = makeEcaRuleMatrix(seq_src)

		# seq_mat �f�[�^�\��
		# next or changeLv [Event,[EventArg1,EventArg2],[ActionList],[ConditionList]]
		# toc [Event,EventArg,[ActionList],[ConditionList]]
		# ActionList [[ActionCode,ActionValue],... ]
		# ConditionList [[Condition,Arg1,Arg2],... ]

		# ���[����]��
		# �C�x���g���ɏ����𕪊�
		#### �����������ꂢ�ɏ��������E�E�E
		case ope_code
		when /next/    # ���̋��ނ�v������C�x���g�̏���
			# ���ݕ\�����Ă��鋳�ރ��W���[�����擾
			#mod_id = ModuleLog.getCurrentModule(self[:user_id] , self[:ent_seq_id])
			mod_id = ModuleLog.getCurrentModule(self[:ent_seq_id])
			if mod_id != -1
				ent_mod = EntModule.find(mod_id)
				mod_name = ent_mod[:module_name]
			else
				mod_name = "start"
			end
			
			# condition�̃}�b�`���O
			n=0
			while n < seq_mat.length do
				if seq_mat[n][0] =~ /#{ope_code}/
					if seq_mat[n][1][0] =~ /#{mod_name}/
						if conditionMatching(seq_mat[n][3])
							break
						end
					end
				end
				n+=1
			end
			
			actionList = Array.new
			# action�̌���
			if n < seq_mat.length
				actionList = seq_mat[n][2]
				if seq_mat[n][1][1] =~ /end/
					actionList.push("view,end")
				else
					actionList.push("view,#{seq_mat[n][1][1]}")
				end
			else
				actionList.push("false,-")
			end
=begin
    when /toc/      # �ڎ�����I���C�x���g�̏���
      # condition�̃}�b�`���O
      n=0
      while n < seq_mat.length do
        if seq_mat[n][0] =~ /#{ope_code}/
            if seq_mat[n][1] =~ /#{self[:event_arg]}/
                if conditionMatching(seq_mat[n][3])
                  break
                end
            end
        end
        n+=1
      end

      actionList = Array.new
      # action�̌���
      if n < seq_mat.length
        actionList = seq_mat[n][2]
        actionList.push("view,#{seq_mat[n][1]}")
      else
        actionList.push("false,-")
      end

    when /changeLv/      # ���x���ύX�̗v���̃C�x���g�̏���
      # condition�̃}�b�`���O
      n=0
      while n < seq_mat.length do
        if seq_mat[n][0] =~ /#{ope_code}/
            if seq_mat[n][1][0] =~ /#{self[:event_arg]}/
                if conditionMatching(seq_mat[n][3])
                  break
                end
            end
        end
        n+=1
      end

      actionList = Array.new
      # action�̌���
      if n < seq_mat.length
        actionList = seq_mat[n][2]
        actionList.push("changeLv,#{seq_mat[n][1][1]}")
      else
        actionList.push("false,-")
      end
=end

		end

    # ActionLog�e�[�u���Ɋi�[�@�g�����U�N�V�����u���b�N
    ActionLog.transaction do
      i=0
      while i < actionList.length do
        code_value = actionList[i].split(/,/)
        action = ActionLog.new
        action[:user_id] = self[:user_id]
        action[:ent_seq_id] = self[:ent_seq_id]
        action[:action_code] = code_value[0]
        action[:action_value] = code_value[1]
        action[:dis_code] = self[:dis_code]
        action.save!
        i+=1
      end
    end
	end
	
	# ���[�����X�g�쐬  
	def makeEcaRuleMatrix(seq_src)
		seq_mat = Array.new
		# Parsing�p�̐��K�\�����`
		opeReg = /(next|toc|changeLv)\((.+?),\[(.*?)\]\)(.*)/
		
		i=0
		while i < seq_src.length do
			eca_array = opeReg.match(seq_src[i]).to_a
			if (eca_array[1] == "next") || (eca_array[1] == "changeLv")
				event_values = eca_array[2].gsub(/\[|\]/,'').split(/,/)
			elsif eca_array[1] == "toc"
				event_values = eca_array[2]
			end
			
			#action���X�g���o��
			actions = eca_array[3].split(/\],\[/)
			actions.each do |t|
				t.gsub!(/\[|\]/,'')
			end
			#condition���X�g���o��
			conditions = eca_array[4]
			if conditions == ""
				# �����������Ƃ��͋󃊃X�g����
				conditions = []
			else
				conditions.gsub!(/:-/,'')
				conditions.gsub!(/\),/,'::')
				conditions.gsub!(/\(/,',')
				conditions.gsub!(/\)/,'')
				conditions = conditions.split(/::/)
			end
			
			seq_mat.push([eca_array[1],event_values,actions,conditions])
			i += 1
		end
		
		return seq_mat
	end

	def conditionMatching(conditionList)
		n=0
		# �ϐ����@�`�F�b�N�p�@���K�\��
		reg_var = /(^[A-Z]+[0-9]*[a-z]*[0-9]*$)/
		# �������]���p�@���K�\��
		reg = /(^[A-Z]+[0-9]*[a-z]*[0-9]*)(!=|<=|>=|==|<|>)([0-9]+$)/ # ex.) Point <= 30
		reg2 = /(^[0-9]+)(!=|<=|>=|==|<|>)([A-Z]+[0-9]*[a-z]*[0-9]*$)/ # ex.) 30 >= Point
		# �ϐ��i�[�p�e�[�u��
		var_tbl = Array.new
		while n < conditionList.length do
			condition = conditionList[n].split(/,/)
			case condition[0]
			when /currentModule/
			when /moduleMember/
			when /getModuleCount/
			when /getTestPoint/
				cur_point = TestLog.getSumPoint(self[:user_id],self[:ent_seq_id],condition[1])
				# �ϐ������擾
				# �K��ɍ���Ȃ��ϐ����͖��� ex.) 10Point(�擪�����l),point(�擪��������)
				# �ϐ��̓��e���㏑������Ă���ǂ����悤�@���u�H�㏑���H������false��Ԃ��H
				reg_var =~ condition[2]
				var_name = $1
				# �ϐ��e�[�u���Ɋi�[
				if var_name
					var_tbl.push([var_name,cur_point.to_i])
				end
			when /getTestTime/
			when /getTestCount/
			when /getCurrentLevel/
				cur_level = LevelLog.getCurrentLevel(self[:user_id],self[:ent_seq_id])
				# �ϐ������擾
				reg_var =~ condition[1]
				var_name = $1
				# �ϐ��e�[�u���Ɋi�[
				if var_name
					var_tbl.push([var_name,cur_level.to_i])
				end
				else
					# �������̕]��
					# �t���O�g��Ȃ��ėǂ����@�@�N�������[��
					if (reg =~ condition[0])
						var_name = $1 # �ϐ���
						symbol = $2 # ��
						value1 = $3.to_i # �l
						value_left_flag = false # �������̒l�����ӂɂ��邩�ۂ��@�t���O
					elsif ( reg2 =~ condition[0])
						var_name = $3
						symbol = $2
						value1 = $1.to_i
						value_left_flag = true
					end
					
					# �ϐ��Ɋi�[����Ă���l���擾
					value2 = nil
					var_tbl.each do |v|
					if v[0] == var_name
						value2 = v[1]
					end
				end
				
				if value2
					case symbol
					when /==/
						flag = value2 == value1
					when /!=/
						flag = value2 != value1
					when /<=/
						if value_left_flag
							flag = value1 <= value2
						else
							flag = value2 <= value1
						end
					when />=/
						if value_left_flag
							flag = value1 >= value2
						else
							flag = value2 >= value1
						end
					when /</
						if value_left_flag
							flag = value1 < value2
						else
							flag = value2 < value1
						end
					when />/
						if value_left_flag
							flag = value1 > value2
						else
							flag = value2 > value1
						end
					end
					unless flag
						return false
					end
				else
					return false
				end
			end
		n+=1
		end

	return true
	end


	validates_inclusion_of :operation_code, :in=>%w(next toc changeLv)
end