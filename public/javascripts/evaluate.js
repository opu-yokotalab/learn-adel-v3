// テスト機構・評価用JavaScript

var blnRequestEnabled = true; // エラーフラグ
// ベースとなるURL
//var baseURL = "/~t_nishi/cgi-bin/prot_test/adel_exam.cgi"; 
//var baseURL = "/~learn/cgi-bin/prot_test_v3/adel_exam.cgi"; 
var baseURL = "/"
// var xmlhttp = null; // XMLHttp object

function fnc_alert(msg){
    window.alert(msg);
};

function set_evaluate(obj) {
    //fnc_alert(obj.id);
    //fnc_alert(obj.name);
    
    //fnc_alert( baseURL + "?mode=" + "pre_evaluate" + "&" + "selected=" + obj.id + "&" + "type=" + obj.getAttribute("type") + "&" + "checked=" + obj.checked + "&" + "value=" + obj.value);

    var xmlhttp = null;
    //fnc_alert("item_" + obj.name);
    var itemDiv = document.getElementById("item_" + obj.name);
    //fnc_alert(itemDiv.id);
    if (itemDiv == null ) {
	//fnc_alert("Error itemDiv null.");
	throw new Error("Can't create itemDiv.");
    }
    //fnc_alert(itemDiv.innerHTML);
    if(blnRequestEnabled) {
	try {
	    xmlhttp = createXMLHttp();
	    if (xmlhttp == null) {
		//fnc_alert("can't create XMLHttp objet.");
		throw new Error("Can't create XMLHttp objet.");
	    }
	    
	    //pageURL = baseURL + "?mode=evaluate&name=" + obj.name + "&ques_pkey=" + obj.getAttribute("ques_pkey");
		pageURL = baseURL + "evaluate/" + obj.name + "/" + obj.getAttribute("ques_pkey");
	    //fnc_alert(pageURL);

	    xmlhttp.open('GET', pageURL);
	    
	    xmlhttp.onreadystatechange = function() {
		if(xmlhttp.readyState == 4) {
		    if(xmlhttp.status == 200) {
			if(xmlhttp.responseText != "") {
			    //fnc_alert(xmlhttp.responseText);
			    itemDiv.innerHTML = ""; // いったん削除
			    itemDiv.innerHTML = xmlhttp.responseText;
			}
		    } else {
			throw new Error("Server sattus error.\n" + xmlhttp.status);
		    }
		}
	    };
	    xmlhttp.send(null);
	} catch (oException) {
	    //blnRequestEnabled = false;
	    //fnc_alert(oException.description);
	}
    }
    
};

function pre_evaluate(obj) {
    //fnc_alert(obj.id);
    //fnc_alert(obj.name);
    //fnc_alert(baseURL + "?mode=" + "pre_evaluate" + "&" + "selected=" + obj.id + "&" + "type=" + obj.getAttribute("type") + "&" + "checked=" + obj.checked + "&" + "value=" + obj.value);
    var xmlhttp = null;
    
    if(blnRequestEnabled) {
	try {
	    xmlhttp = createXMLHttp();
	    if (xmlhttp == null) {
		//fnc_alert("can't create XMLHttp objet.");
		throw new Error("Can't create XMLHttp objet.");
	    }

	    // 出題形式に合わせて引数を変える
	    if (obj.getAttribute("type") == "radio") {
		//pageURL = baseURL + "pre_evaluate?selected=" + obj.id + "&type=" + obj.getAttribute("type") + "&value=" + obj.value + "&ques_pkey=" + obj.getAttribute("ques_pkey");
		pageURL = baseURL + "pre_evaluate/" + obj.id + "/" + obj.getAttribute("type") + "/" + obj.value + "/" + obj.getAttribute("ques_pkey");
	    } else if(obj.getAttribute("type") == "checkbox") {
		//pageURL = baseURL+ "pre_evaluate?selected=" + obj.id + "&type=" + obj.getAttribute("type") + "&checked=" + obj.checked + "&ques_pkey=" + obj.getAttribute("ques_pkey");
		pageURL = baseURL + "pre_evaluate/" + obj.id + "/" + obj.getAttribute("type") + "/" + obj.value + "/" + obj.getAttribute("ques_pkey");
	    } else if(obj.getAttribute("type") == "text") {
		//pageURL = baseURL+ "pre_evaluate?selected=" + obj.id + "&type=" + obj.getAttribute("type") + "&value=" + obj.value + "&ques_pkey=" + obj.getAttribute("ques_pkey");
		pageURL = baseURL + "pre_evaluate/" + obj.id + "/" + obj.getAttribute("type") + "/" + $(obj.id).value + "/" + obj.getAttribute("ques_pkey");
	    }
	    //fnc_alert(pageURL);

	    xmlhttp.open('GET', pageURL);
	    
	    xmlhttp.onreadystatechange = function() {
		if(xmlhttp.readyState == 4) {
		    if(xmlhttp.status == 200) {
			if(xmlhttp.responseText != "") {
			    window.status = xmlhttp.responseText
			    //fnc_alert(xmlhttp.responseText);
			}
		    } else {
			throw new Error("Server sattus error.\n" + xmlhttp.status);
		    }
		}
	    };
	    xmlhttp.send(null);
	} catch (oException) {
	    //blnRequestEnabled = false;
	    //fnc_alert(oException.description);
	}
    }
};

// XMLHttpsオブジェクト作成
function createXMLHttp()
{
    try {
	return new ActiveXObject ("Microsoft.XMLHTTP");
    }catch(e){
	try {
	    return new XMLHttpRequest();
	}catch(e) {
	    return null;
	}
    }
    return null;
};
