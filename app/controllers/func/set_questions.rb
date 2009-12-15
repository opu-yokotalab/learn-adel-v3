# HTTP通信
require "net/http"

# REXML
require "rexml/document"

# Ruby-XSLT
require "xml/xslt"

# 文字コード変換
#require "kconv"

# MD5の計算用
require "digest/md5"

class Set_question

  include REXML

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

  # 初期化
  def initialize(user_id)
    # テスト情報
    @test_id = String.new

    # ユーザid
    @user_id = user_id.to_s
  end

    # 多次元配列による出題テーブル
  # [{グループid, 配点, 問題id, 出題タイプ, 評価基準点, 正解フィルタ, 問題タイプ, 固有識別子}, ...]
#    @setTable = make_table(input_xml)

    # 処理が完了した出題テーブル
 #   return @setTable

  
  # 呼出し記述を内部の出題用テーブルに変換
  def make_table(input_xml, base_eXist_host, base_eXist_port, base_db_uri)
    # Documentオブジェクトを生成
    #tmpDoc = REXML::Document.new(input_xml)
    tmpDoc = input_xml
#puts tmpDoc
    # 呼び出し記述がおかしい場合停止する
    if tmpDoc.elements["//examination"] == nil then
#puts "Error"
      return -1
    end
    
    # テーブルの行
    setAry = Array.new
    
    # テストidの取得
    @test_id = tmpDoc.elements["//examination"].attributes["id"]


    # 記録時間
    setTime = Date.today.to_s + " " + Time.now.strftime("%X")
  
    
    # 各グループ単位の呼出しについて
    tmpDoc.get_elements("//examination/group").each{|tmpElem|
      grpAttr = tmpElem.attributes
      # グループidの取得
      group_id = grpAttr["id"]
      # 配点の取得
      mark = grpAttr["mark"]
      
      # グループ内の各問題の呼出しについて
      tmpElem.get_elements("item").each{|tmpItm|
        itmAttr = tmpItm.attributes
        # 問題idの取得
        #item_id = itmAttr["id"]
        item_id = ""
        # 問題形式の取得
        item_type = itmAttr["type"]
        if item_type != "random" and item_type != "type" then
          item_id = item_type
        end
        
        # 評価基準点
        tmpOpt =  tmpItm.elements["passing_grade"]
        if tmpOpt != nil then
          ques_pass =  tmpOpt.get_text.to_s
        else
          ques_pass = ""
        end
        
        # 問題形式
        tmpOpt =  tmpItm.elements["selection_type"]
        if tmpOpt != nil then
          # id直接指定以外の問題形式の場合、ここで出題する問題を確定
          ques_type = tmpOpt.get_text.to_s
        else
          ques_type = ""
        end
        
        # 過去の出題(正解?)履歴を考慮するか
        tmpOpt =  tmpItm.elements["selection_correct"]
        if tmpOpt != nil then
          ques_correct = tmpOpt.get_text.to_s
        else
          ques_correct = ""
        end

        # 固有識別子(pkey)の生成
        pkeyInt = Time.now.tv_sec + rand(1000000)
        pkey = Digest::MD5.new.update(pkeyInt.to_s).to_s
#puts "make_table: " + pkey        
         # ハッシュを配列に格納
        setAry << {"group_id" => group_id, "mark" => mark, "item_id" => item_id, "ques_pass" => ques_pass,"ques_type" => item_type , "selection_type" => ques_type, "ques_correct" => ques_correct, "time" => setTime, "test_key" => pkey}

        # 必要な分だけ初期化
        item_id = ""
        ques_pass = ""
        item_type = ""
        ques_type = ""
        ques_correct = ""
      }
    }
    # 未決定の問題を確定させる
    setAry = set_table(setAry, base_eXist_host, base_eXist_port, base_db_uri)

    # 中間XMLに変換
    #make_xml(setAry)
    
    # テーブルを返す
    return setAry
  end

  # 出題テーブル中の問題形式[random,type]について問題idを確定させる
  def set_table(tbl, base_eXist_host, base_eXist_port, base_db_uri)
    # 初めに確定済みのグループidと問題idを列挙
    # {"group_id" => [item_id, ...]}
    tmpSetList = Hash.new{|h, key| h[key] = []}
    
    tbl.each{|tblLine|
      if tblLine["ques_type"] != "random" and tblLine["ques_type"] != "type" then
        tmpSetList[tblLine["group_id"]] << tblLine["ques_type"]
      end
    }

    # 出題テーブルの先頭優先で順に出題する問題を確定
    tmpItemId = ""
    tbl.each_with_index{|tblLine, idx|
      if tblLine["ques_type"] == "random" then
        # ランダム出題
        tmpItemId = get_itemId(tblLine["group_id"], "", tmpSetList[tblLine["group_id"]], "random", base_eXist_host, base_eXist_port, base_db_uri)
        
        # うまく取得できているようだったらテーブルの値入れ替え
        if tmpItemId != "" then
          tmpSetList[tblLine["group_id"]] << tmpItemId
          tbl[idx]["item_id"] = tmpItemId
        end
        
      elsif tblLine["ques_type"] == "type" then
        # 形式指定出題
        tmpItemId  << get_itemId(tblLine["group_id"], tblLine["selection_type"], tmpSetList[tblLine["group_id"]], "type", base_eXist_host, base_eXist_port, base_db_uri)
        
        # うまく取得できているようだったらテーブルの値入れ替え
        if tmpItemId != "" then
          tmpSetList[tblLine["group_id"]] << tmpItemId
          tbl[idx]["item_id"] = tmpItemId
        end
      end      
    }
    
    #p tmpSetList
    #p tbl

    # 書き換えた出題テーブルを返す
    return tbl
  end
  
 # 出題テーブルから中間XMLを生成
  def make_xml(tbl, base_eXist_host, base_eXist_port, base_db_uri, base_inputType_uri)
    # 念のためユーザidのチェック
    if @user_id == "" then
      return -1
    end

    # ルートノードの作成
    tmpRoot = REXML::Element.new("exam")
    tmpRoot.add_attribute("user_id", @user_id )
    
    # 要素１つずつ処理をしていく
    tmpElem = REXML::Element.new
    tbl.each{|tblLine|
      tmpElem = get_item(tblLine["group_id"], tblLine["item_id"], base_eXist_host, base_eXist_port, base_db_uri)

      # 一回属性値(item_id)を削除して、変換用のid(group_id + "_" + item_id)を入れる
      tmpElem.delete_attribute("id")
      tmpElem.add_attribute("id", tblLine["group_id"] + "_" + tblLine["item_id"] )

      # ついでにxhtmlのinput要素のtype属性値を決める
      tmpType = tmpElem.attributes["type"]
      tmpElem.delete_attribute("type")
      tmpElem.add_attribute("type", convInputType(tmpType, base_eXist_host, base_eXist_port, base_inputType_uri))
#puts "make_xml: " + tblLine["test_key"]
      # 固有識別子を追加
      tmpElem.add_attribute("ques_pkey", tblLine["test_key"])
      
      # ルートノードに追加
      tmpRoot.add_element(tmpElem)
    }

    return tmpRoot
  end
  
  # XHTMLファイルを生成
  def make_xhtml(input_xml, base_eXist_host, base_eXist_port, base_xslt_uri)  
        
    # xsltオブジェクト
    xslt = XML::XSLT.new()
    xslt.xml = input_xml.to_s

    # XSLTスタイルシートはXMLデータベースから持ってくる
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_xslt_uri)
    res = http.request(req)
   
    xslt_doc = REXML::Document.new(res.body)
    
    xslt.xsl = xslt_doc
    out_xml = xslt.serve() # Stringオブジェクト
    
    outDoc = REXML::Document.new(out_xml)
    return outDoc
    #puts @outDoc.class
    #puts @outDoc
    #puts @tmpDoc   
  end

  # グループidと問題idから該当する問題記述を取得
  def get_item(group_id, item_id, base_eXist_host, base_eXist_port, base_db_uri)
#    p group_id
#    p item_id

    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_db_uri + group_id + ".xml?_query=//problem_set/item[@id=%22" + item_id  + "%22]")
    res = http.request(req)

    docElem = REXML::Document.new(res.body)
    elem = docElem.elements["//item"]
# p elem   
    return elem
  end
  
  # 明示的な指定以外の出題方法で出題可能な問題idを返す
  def get_itemId(group_id, item_type, itemList, mode, base_eXist_host, base_eXist_port, base_db_uri)

    # 出題方法で接続先変更
    if mode == "type" then
      reqStr = base_db_uri + group_id + ".xml?_query=//problem_set/item[@type=%22" + item_type  + "%22]"
      elsif mode == "random" then
      reqStr = base_db_uri + group_id + ".xml?_query=//problem_set/item"
    end    

    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(reqStr)
    res = http.request(req)

    # Documentオブジェクトを生成
    doc = REXML::Document.new(res.body)

    # 指定された種類の問題を列挙
    tmpElem = doc.get_elements("//item")

    # 該当ノードがある気配
    if tmpElem.size != 0 then

      settableList = Array.new
      # 出題可能な問題idを列挙
      tmpElem.each{|elemLine|
        settableList << elemLine.attributes["id"].to_s
      }

      # 出題可能な問題を計算。なかったら終了
      tmpList = settableList - itemList
      if tmpList.length == 0 then
        # 出題可能な問題なし
        return -1
      end

      tmpSize = tmpList.length # 問題数を取得    

      # 列挙された問題から適当に問題idを選択
      rndIndex = tmpList[rand(tmpSize)]

      return rndIndex
    end

    # 該当ノード無し
    return -1
  end

  # テストidを返す
  def get_testId
    return @test_id
  end
  
  # 問題記述中の問題形式から解答形式を決定
  def convInputType(type, base_eXist_host, base_eXist_port, base_inputType_uri)
    # Webサーバからドキュメントを取得
    http = Net::HTTP.new(base_eXist_host, base_eXist_port)
    req = Net::HTTP::Get.new(base_inputType_uri)
    res = http.request(req)
    
    docElem = REXML::Document.new(res.body)

    # 該当するtype属性値を持つノードを探す
    srchElem = docElem.get_elements("/input_type/input/object[@type=\"" + type + "\"]")

    # そのノードの親のtype属性値を返す
    return srchElem[0].parent.attributes["type"].to_s
    
  end
  
  # テーブル中の要素をシャッフル
  def randomize(tbl)
    tbl.sort_by{rand}
    return tbl
  end
end
