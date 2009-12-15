class OperationLog < ActiveRecord::Base
	belongs_to :ent_seq
	after_save :rule_evaluate

	def rule_evaluate
		# イベント取得
		ope_code = self[:operation_code]
		# SEQログから現在のECAルールを取得
		ent_seq = EntSeq.find(self[:ent_seq_id])
		seq_src = ent_seq[:seq_src]
		# 空白と改行の削除　→　.で分割
		seq_src = seq_src.gsub(/(\s|\n)/,'').split(/\./)
		
		# EcaRuleMatrixの作成
		seq_mat = makeEcaRuleMatrix(seq_src)
		
		# seq_mat データ構造
		# next or changeLv [Event,[EventArg1,EventArg2],[ActionList],[ConditionList]]
		# toc [Event,EventArg,[ActionList],[ConditionList]]
		# ActionList [[ActionCode,ActionValue],... ]
		# ConditionList [[Condition,Arg1,Arg2],... ]
		
		# ルールを評価
		# イベント毎に処理を分岐
		#### もう少しきれいに書きたい・・・
		case ope_code
		when /next/    # 次の教材を要求するイベントの処理
			# 現在表示している教材モジュールを取得
			mod_id = ModuleLog.getCurrentModule(self[:user_id] , self[:ent_seq_id])
			if mod_id != -1
				ent_mod = EntModule.find(mod_id)
				mod_name = ent_mod[:module_name]
			else
				mod_name = "start"
			end
			
			# conditionのマッチング
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
			# actionの決定
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
		when /toc/      # 目次から選択イベントの処理
			# conditionのマッチング
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
			# actionの決定
			if n < seq_mat.length
				actionList = seq_mat[n][2]
				actionList.push("view,#{seq_mat[n][1]}")
			else
				actionList.push("false,-")
			end
		when /changeLv/      # レベル変更の要求のイベントの処理
			# conditionのマッチング
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
			# actionの決定
			if n < seq_mat.length
				actionList = seq_mat[n][2]
				actionList.push("changeLv,#{seq_mat[n][1][1]}")
			else
				actionList.push("false,-")
			end
		
		end
		
		# ActionLogテーブルに格納　トランザクションブロック
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
	
	# ルールリスト作成  
	def makeEcaRuleMatrix(seq_src)
		seq_mat = Array.new
		# Parsing用の正規表現を定義
		opeReg = /(next|toc|changeLv)\((.+?),\[(.*?)\]\)(.*)/
		
		i=0
		while i < seq_src.length do
			eca_array = opeReg.match(seq_src[i]).to_a
			if (eca_array[1] == "next") || (eca_array[1] == "changeLv")
				event_values = eca_array[2].gsub(/\[|\]/,'').split(/,/)
			elsif eca_array[1] == "toc"
				event_values = eca_array[2]
			end
			
			#actionリスト取り出し
			actions = eca_array[3].split(/\],\[/)
			actions.each do |t|
				t.gsub!(/\[|\]/,'')
			end
			#conditionリスト取り出し
			conditions = eca_array[4]
			if conditions == ""
				# 条件が無いときは空リストを代入
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
		# 変数名　チェック用　正規表現
		reg_var = /(^[A-Z]+[0-9]*[a-z]*[0-9]*$)/
		# 条件式評価用　正規表現
		reg = /(^[A-Z]+[0-9]*[a-z]*[0-9]*)(!=|<=|>=|==|<|>)([0-9]+$)/ # ex.) Point <= 30
		reg2 = /(^[0-9]+)(!=|<=|>=|==|<|>)([A-Z]+[0-9]*[a-z]*[0-9]*$)/ # ex.) 30 >= Point
		# 変数格納用テーブル
		var_tbl = Array.new
		while n < conditionList.length do
			condition = conditionList[n].split(/,/)
			case condition[0]
			when /currentModule/
			when /moduleMember/
			when /getModuleCount/
			when /getTestPoint/
				cur_point = TestLog.getSumPoint(self[:user_id],self[:ent_seq_id],condition[1])
				# 変数名を取得
				# 規約に合わない変数名は無視 ex.) 10Point(先頭が数値),point(先頭が小文字)
				# 変数の内容が上書きされてたらどうしよう　放置？上書き？そこでfalseを返す？
				reg_var =~ condition[2]
				var_name = $1
				# 変数テーブルに格納
				if var_name
					var_tbl.push([var_name,cur_point.to_i])
				end
			when /getTestTime/
			when /getTestCount/
			when /getCurrentLevel/
				cur_level = LevelLog.getCurrentLevel(self[:user_id],self[:ent_seq_id])
				# 変数名を取得
				reg_var =~ condition[1]
				var_name = $1
				# 変数テーブルに格納
				if var_name
					var_tbl.push([var_name,cur_level.to_i])
				end
			else
				# 条件式の評価
				# フラグ使わなくて良い方法　誰かおせーて
				if (reg =~ condition[0])
					var_name = $1 # 変数名
					symbol = $2 # 式
					value1 = $3.to_i # 値
					value_left_flag = false # 条件式の値が左辺にあるか否か　フラグ
				elsif ( reg2 =~ condition[0])
					var_name = $3
					symbol = $2
					value1 = $1.to_i
					value_left_flag = true
				end
				
				# 変数に格納されている値を取得
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