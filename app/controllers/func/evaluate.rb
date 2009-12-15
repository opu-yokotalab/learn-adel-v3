#!/bin/env ruby
#
# 評価機構モジュール
#


# HTTP通信
require "net/http"

# REXML
require "rexml/document"

# Ruby-XSLT
#require "xml/xslt"

# 文字コード変換
#require "kconv"

# Ruby-PostgreSQL
#require "postgres"

# MD5の計算用
require "digest/md5"


class Evaluate

  ## おおまかな処理の流れ
  # 【部分評価】
  # 解答キー(eval_key)と解答したグループidと問題id、選択肢idを照合
  # 評価結果をRDBへ格納
  
  # 初期化
  def initialize
    return 0
  end

  # プレ評価
  # 引数：ques_pkey(出題した問題の固有識別子)
  #       selectHash(解答に含まれる情報を分解したハッシュ)
  #       setHisHash(ques_pkeyで特定される問題の出題履歴)
  def preEvaluate(type, ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    # 問題形式によって評価方法を変える
    case type
    when "radio" then # 単一選択
      result = evalRadioType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    when "checkbox" then # 複数選択
      # 複数選択の評価は、選択肢を選んだ履歴を考慮する必要がある
      #return -1
      result = evalCheckType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    when "text" then # テキスト入力
      # テキスト入力の評価は今の所単純比較
      #return -1
      result = evalWordType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    else # その他拡張用
      # 好きに実装
      return -1
    end

    # 評価結果を返す
    return result
  end

  # 単一選択問題の評価
  # 複数選択、自由記述は今後の課題と言う事でひとつ
  def evalRadioType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    # 履歴から出題した問題を取得
    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_db_uri + setHisHash["group_id"] + ".xml?_query=//problem_set/item[@id=%22" + setHisHash["ques_id"]  + "%22]")
    res = http.request(req)
    
    docElem = REXML::Document.new(res.body)
    elem = docElem.elements["//item"]
 
    # 問題から評価するための情報を取得
    # 正解の重み
    crctWeight = elem.elements["./evaluate/weight"].attributes["correct"].to_i
    # 不正解の重み
    incrctWeight = elem.elements["./evaluate/weight"].attributes["incorrect"].to_i
    # 正解の選択肢
    correctId = elem.elements["./evaluate/correct"].attributes["id"].to_s
    # 閾値
    score = elem.elements["./evaluate/score"].get_text.to_s.to_i
    # 正解時に与えられるポイント
    crctPoint = elem.elements["./evaluate/point"].get_text.to_s.to_i

    # 正解の選択肢を配列に
    # (正解の選択肢が複数の時に…と考えたけど使うかどうか微妙)
    crctAry = correctId.split(",")

    # 正解数
    correctNum = 0
    # 不正解数
    incorrectNum = 0
    
    # 選んだ選択肢が正解か？
    if crctAry.include?(value) then
      correctNum += 1
    else
      incorrectNum += 1
    end

    # 正解と不正解それぞれの重みを計算
    cWeight = correctNum * crctWeight
    icWeight = incorrectNum * incrctWeight
    totalWeight = (correctNum * crctWeight) + (incorrectNum * incrctWeight)
    
    # 最終的な評価結果
    total_point = 0
    if totalWeight >= score then # 閾値より大きい
      total_point = crctPoint
    else
      total_point = 0
    end

    # 固有識別子(pkey)の生成
    pkeyInt = Time.now.tv_sec + rand(1000000)
    pkey = Digest::MD5.new.update(pkeyInt.to_s).to_s

    # 記録時間
    evalTime = Date.today.to_s + " " + Time.now.strftime("%X")   
    
    # 評価結果を返す
    evalResultHash = Hash.new
    evalResultHash = {"chk_selection" => value.to_s, "eval_result" => total_point.to_s, "crct_weight" => cWeight.to_s, "incrct_weight" => icWeight.to_s, "total_weight" => totalWeight.to_s, "eval_pkey" => pkey, "time" => evalTime, "total_point" => crctPoint.to_s}

    return evalResultHash
  end


  # 複数選択問題の評価
  # 複数選択、自由記述は今後の課題と言う事でひとつ
  def evalCheckType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    # 履歴から出題した問題を取得
    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_db_uri + setHisHash["group_id"] + ".xml?_query=//problem_set/item[@id=%22" + setHisHash["ques_id"]  + "%22]")
    res = http.request(req)
    
    docElem = REXML::Document.new(res.body)
    elem = docElem.elements["//item"]
 
    # 問題から評価するための情報を取得
    # 正解の重み
    crctWeight = elem.elements["./evaluate/weight"].attributes["correct"].to_i
    # 不正解の重み
    incrctWeight = elem.elements["./evaluate/weight"].attributes["incorrect"].to_i
    # 正解の選択肢
    correctId = elem.elements["./evaluate/correct"].attributes["id"].to_s
    # 閾値
    score = elem.elements["./evaluate/score"].get_text.to_s.to_i
    # 正解時に与えられるポイント
    crctPoint = elem.elements["./evaluate/point"].get_text.to_s.to_i

    # 正解の選択肢を配列に
    # (正解の選択肢が複数の時に…と考えたけど使うかどうか微妙)
    crctAry = correctId.split(",")

    # 正解数
    correctNum = 0
    # 不正解数
    incorrectNum = 0

    #正解の個数をカウント
    ansNum = 0
    
    # 選んだ選択肢が正解か？
    # 正解かどうかの判定

    #デバグ用表示
    #print("value=",value,"\n")
    #print("corAry=",crctAry,"\n")

    #パターンマッチングで正解かどうかの判定
    #for ans in crctAry do
    	#デバグ用コード
	#print("ans=",ans,"\n")

	#判定
    	#if /#{ans}/ =~ "#{value}" then
    	   #correctNum = correctNum + 1
	
	#if文の終了  
	#end
	
	#ansNum += 1
    #for文の終了
    #end

    #もし正解と一致しないときは、不正解にする
    #if(correctNum < ansNum) then
    	#incorrectNum =+ 1
    #else
	#incorrectNum = 0
    #end  
    
    #ここもデバグ用のプリント
    #print("corNum=",correctNum,"\n");
    #print("incorNum=",incorrectNum,"\n");

    #if crctAry.include?(value) then
    #correctNum += 1
    #else
    #incorrectNum += 1
    #end

    # 正解と不正解それぞれの重みを計算
    cWeight = correctNum * crctWeight
    icWeight = incorrectNum * incrctWeight
    totalWeight = (correctNum * crctWeight) + (incorrectNum * incrctWeight)
    
    # 最終的な評価結果
    total_point = 0
    if totalWeight >= score then # 閾値より大きい
      total_point = crctPoint
    else
      total_point = 0
    end

    # 固有識別子(pkey)の生成
    pkeyInt = Time.now.tv_sec + rand(1000000)
    pkey = Digest::MD5.new.update(pkeyInt.to_s).to_s

    # 記録時間
    evalTime = Date.today.to_s + " " + Time.now.strftime("%X")   
    
    # 評価結果を返す
    evalResultHash = Hash.new
    evalResultHash = {"chk_selection" => value.to_s, "eval_result" => total_point.to_s, "crct_weight" => cWeight.to_s, "incrct_weight" => icWeight.to_s, "total_weight" => totalWeight.to_s, "eval_pkey" => pkey, "time" => evalTime, "total_point" => crctPoint.to_s}

    return evalResultHash
  end


  # 穴埋め問題の評価
  def evalWordType(ques_pkey, value, setHisHash, base_eXist_host, base_eXist_port, base_db_uri)
    # 履歴から出題した問題を取得
    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_db_uri + setHisHash["group_id"] + ".xml?_query=//problem_set/item[@id=%22" + setHisHash["ques_id"]  + "%22]")
    res = http.request(req)
    
    docElem = REXML::Document.new(res.body)
    elem = docElem.elements["//item"]
 
    # 問題から評価するための情報を取得
    # 正解の重み
    crctWeight = elem.elements["./evaluate/weight"].attributes["correct"].to_i
    # 不正解の重み
    incrctWeight = elem.elements["./evaluate/weight"].attributes["incorrect"].to_i
    # 正解の選択肢
    correctId = elem.elements["./evaluate/correct"].get_text.to_s
    # 閾値
    score = elem.elements["./evaluate/score"].get_text.to_s.to_i
    # 正解時に与えられるポイント
    crctPoint = elem.elements["./evaluate/point"].get_text.to_s.to_i

    # 正解の選択肢を配列に
    # (正解の選択肢が複数の時に…と考えたけど使うかどうか微妙)
    crctAry = correctId.split(",")
    #crctAry = correctId

    # 正解数
    correctNum = 0
    # 不正解数
    incorrectNum = 0
    
    # 正解かどうかの判定？
    #デバグ用表示
    #print("value=",value,"\n")
    #print("corAry=",crctAry[0],"\n")

    #パターンマッチングで正解かどうかの判定
    for ans in crctAry do
    	#過去のコード＆デバグ用
    	#if /#{correctId}/ =~ "#{value}" then
	#print("ans=",ans,"\n")

	#判定
    	if /#{ans}/ =~ "#{value}" then
    	  correctNum += 1
	  
	  #過去の産物
	  #if crctAry.include?(value) then
     	  #print("correct\n")
	
	#if文の終了  
	end

    #for文の終了
    end

    #else
    #print("false\n")

    #もし正解と一致しないときは、不正解にする
    if(correctNum == 0) then
      incorrectNum += 1
    end
    
    #ここもデバグ用のプリント
    #print("corNum=",correctNum,"\n");
    #print("incorNum=",incorrectNum,"\n");

    # 正解と不正解それぞれの重みを計算
    cWeight = correctNum * crctWeight
    icWeight = incorrectNum * incrctWeight
    totalWeight = (correctNum * crctWeight) + (incorrectNum * incrctWeight)
    
    # 最終的な評価結果
    total_point = 0
    if totalWeight >= score then # 閾値より大きい
      total_point = crctPoint
    else
      total_point = 0
    end

    # 固有識別子(pkey)の生成
    pkeyInt = Time.now.tv_sec + rand(1000000)
    pkey = Digest::MD5.new.update(pkeyInt.to_s).to_s

    # 記録時間
    evalTime = Date.today.to_s + " " + Time.now.strftime("%X")   
    
    # 評価結果を返す
    evalResultHash = Hash.new
    evalResultHash = {"chk_selection" => value.to_s, "eval_result" => total_point.to_s, "crct_weight" => cWeight.to_s, "incrct_weight" => icWeight.to_s, "total_weight" => totalWeight.to_s, "eval_pkey" => pkey, "time" => evalTime, "total_point" => crctPoint.to_s}

    return evalResultHash
  end




  # 評価結果の正規化(mode=result)

  def evaluate(tbl)
    # 正規化した評価結果を返す

    # 配点をまとめる
    markHash = Hash.new
    tbl.each{|tblLine|
      markHash[tblLine["group_id"]] = tblLine["group_mark"].to_i
    }

    # グループごとの獲得した得点をまとめる
    grpPntHash = Hash.new{|h,key|h[key] = []}
    tbl.each{|tblLine|
      grpPntHash[tblLine["group_id"]] << tblLine["eval_result"].to_i
    }
    # それぞれのグループの得点を加算
    sumNum = 0
    grpPntHash.each{|key, value|
      value.each{|valLine|
        sumNum += valLine.to_i
      }
      grpPntHash[key] = sumNum
      sumNum = 0
    }

    # グループごとの満点を求める
    grpFullPntHash = Hash.new{|h,key|h[key] = []}
    tbl.each{|tblLine|
      grpFullPntHash[tblLine["group_id"]] << tblLine["total_point"].to_i
    }
    # それぞれのグループの得点を加算(総得点)
    sumNum = 0
    grpFullPntHash.each{|key, value|
      value.each{|valLine|
        sumNum += valLine.to_i
      }
      grpFullPntHash[key] = sumNum
      sumNum = 0
    }

    # 得点率を計算
    pntRateHash = Hash.new
    grpFullPntHash.each{|key, value|
      pntRateHash[key] = grpPntHash[key].to_f / grpFullPntHash[key].to_f
    }

    # 得点率*配点で実際の得点を計算
    normalizeHash = Hash.new
    pntRateHash.each{|key,value|
      normalizeHash[key] = ((markHash[key] * pntRateHash[key]).round).to_s
    }
    return normalizeHash
  end
end
