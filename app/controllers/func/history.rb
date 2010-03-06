# MD5の計算用
require "digest/md5"

class History < ApplicationController

  ## 基本動作
  # 【出題履歴】
  # 出題時に作成した出題テーブルを元に履歴を作成

  # 初期化
  def initialize
    return 0
  end
  
  # 出題テーブルの内容をRDBに格納
	def put_setHistory(user_id, test_id, tblLine)
		exam_log = Examination.new
		
		exam_log[:user_id]		= user_id
		exam_log[:test_id]		= test_id
		exam_log[:group_id]		= tblLine["group_id"]
		exam_log[:group_mark]	= tblLine["mark"]
		exam_log[:ques_id]		= tblLine["item_id"]
		exam_log[:ques_pass]	= tblLine["ques_pass"]
		exam_log[:test_key] 	= Digest::MD5.new.update(tblLine["time"]).to_s
		exam_log[:examination_pkey] = tblLine["test_key"]
		
		exam_log.save!
	end

	# 履歴を返す
	def get_setHistory(pkey)
	# 履歴格納先
		setHisHash = Hash.new
		
		res = Examination.find(:first, :conditions=>"examination_pkey = '#{pkey}'")
		
		setHisHash["id"]			= res[:id]
		setHisHash["user_id"]		= res[:user_id]
		setHisHash["test_id"]		= res[:test_id].to_s
		setHisHash["group_id"]		= res[:group_id].to_s
		setHisHash["group_mark"]	= res[:group_mark]
		setHisHash["ques_id"]		= res[:ques_id].to_s
		setHisHash["ques_pass"]		= res[:ques_pass]
		setHisHash["test_key"]		= res[:test_key].to_s
		setHisHash["examination_pkey"] = res[:examination_pkey].to_s
		setHisHash["created_at"]	= res[:created_at]
		setHisHash["updated_at"]	= res[:updated_at]
		
		return setHisHash
	end
	
	# プレ評価の履歴を記録
	def put_preEvalHistory(eval_key, evalResultHash)
		pre_evaluate_log = PreEvaluate.new
		
		pre_evaluate_log[:evaluate_pkey]	= evalResultHash["eval_pkey"]
		pre_evaluate_log[:eval_key]			= eval_key
		pre_evaluate_log[:chk_selection]	= evalResultHash["chk_selection"]
		pre_evaluate_log[:eval_result]		= evalResultHash["eval_result"]
		pre_evaluate_log[:comp_eval]		= false
		pre_evaluate_log[:crct_total_weight]= evalResultHash["crct_weight"]
		pre_evaluate_log[:incrct_total_weight]= evalResultHash["incrct_weight"]
		pre_evaluate_log[:total_weight]		= evalResultHash["total_weight"]
		pre_evaluate_log[:total_point]		= evalResultHash["total_point"]
		
		pre_evaluate_log.save!
		
		return 0
	end

	# プレ評価の履歴を返す
	def get_preEvalHistory(pkey)
		# 履歴格納先
		preHisHash = Hash.new

		
		res = PreEvaluate.find(:first, :conditions=>"eval_key = '#{pkey}'", :order=>"created_at DESC")
		
		preHisHash["id"]			= res[:id]
		preHisHash["chk_selection"]	= res[:chk_selection]
		preHisHash["eval_result"]	= res[:eval_result]
		preHisHash["total_point"]	= res[:total_point]
		preHisHash["comp_eval"]		= res[:comp_eval]
		preHisHash["crct_total_weight"] = res[:crct_total_weight]
		preHisHash["incrct_total_weight"] = res[:incrct_total_weight]
		preHisHash["total_weight"]	= res[:total_weight]
		preHisHash["eval_key"]		= res[:eval_key].to_s
		preHisHash["evaluate_pkey"]	= res[:evaluate_pkey].to_s
		preHisHash["created_at"]	= res[:created_at]
		preHisHash["updated_at"]	= res[:updated_at]
		
		return preHisHash
	end

	# 確定した解答の履歴を記録
	def put_evalHistory(pkey)
		PreEvaluate.update_all("comp_eval = 'true'", "evaluate_pkey='#{pkey}'")
		
		return 0
	end

  # 確定した解答の履歴を返す
  def get_evalHistory(test_key)
	# 履歴格納先
	evalAry = Array.new
	eval_key = String.new
	group_id = String.new
	group_mark = String.new
	eval_result = String.new
	total_point = String.new
    
	# 問合せ
	res = Examination.find(:all, :conditions=>"test_key='#{test_key}'")

	# 該当するものそれぞれについて
	res.each{|resultLine|
		# 必要なものを抜き出し
		eval_key = resultLine[:examination_pkey]
		group_id = resultLine[:group_id]
		group_mark = resultLine[:group_mark]

		# プレ評価のテーブルにも
		sql = PreEvaluate.find(:all, :conditions=>"eval_key='#{eval_key}' AND comp_eval='true'")

		sql.each{|sqlLine|
			eval_result = sqlLine[:eval_result]
			total_point = sqlLine[:total_point]
		}
		# ハッシュを配列に格納
		evalAry << {"group_id" => group_id, "group_mark" => group_mark, "eval_result" => eval_result, "total_point" => total_point, "eval_key" => eval_key}
	}

	return evalAry
end

	# 指定されたuser_idを持つ最新のtest_keyを返す
	def get_testidByUserid(user_id)
		# 問合せ
		res = Examination.find(:first, :conditions=>"user_id='#{user_id}'", :order=>"created_at DESC")
		
		return res[:test_key]
	end
end