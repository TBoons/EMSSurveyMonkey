<cfscript>
	/*
		TODO:
			Copy apiKeys.cfm in to same folder as this file
			Create DB Tables
			Change 'dbo.surveryMonkey' in two queries to actual database scema and table
			Set devMode = false;

			--SQL Command to create table
			CREATE TABLE
				dbo.surveryMonkey
			(
				id bigint NOT NULL auto_increment
				,pageTitle varchar(255)
				,questionHeading varchar(255)
				,rowText varchar(255)
				,answerText varchar(1000)
				,answerWeight integer
				,responseId bigint
				,responseTime timestamp
				,surveyId bigint
				,questionId bigint
				,questionNo integer
				,PRIMARY KEY (id)
			)

	*/

	if ( !structKeyExists(url,'surveyId') ){ //Required URL parameter... Throws error is missing
		throw "Missing url parameter surveyId";
	}
	satifactionSurveyID = url.surveyId; //69797272 is the survey for LCEMS Customer Satifaction Survey

	include "apiKeys.cfm"; //API keys in this cfm file. authKey & apiKey must be set in here

	devMode = false; //Set to false once DB is setup and datasource on two queries is changed from TODO to actual datasource
</cfscript>


<cfif devMode >
	<cfset qryFindMaxTimeStamp.recordcount = 0 >
<cfelse>
	<cfquery datasource="emsapps" name="qryFindMaxTimeStamp">
		SELECT
			MAX( sr.responseTime ) AS lastSurveyTime
		FROM
			dbo.surveryMonkey sr
		WHERE
			sr.surveyId = <cfqueryparam value="#url.surveyId#" cfsqltype="cf_sql_bigint" />
	</cfquery>
</cfif>

<cfscript>
	if ( qryFindMaxTimeStamp.recordcount >= 1 && isDate( qryFindMaxTimeStamp.lastSurveyTime ) ){
		newDate = dateAdd("s", 1, qryFindMaxTimeStamp.lastSurveyTime); //add 1 second to latest record for query filter
		surveyQueryTime = dateFormat(newDate, "YYYY-MM-DDT") & timeFormat(newDate, "HH:MM:ss");
	} else {
		surveyQueryTime = "2016-08-20T00:00:00";
	}
	writeDump(surveyQueryTime);
	/*
		This will get surveys in LCEMS's Survey Monkey Account
	*/

	// new http();
	// surveyMonkeySurveysHTTP = new http();
	// surveyMonkeySurveysHTTP.setMethod("GET");
	// surveyMonkeySurveysHTTP.setUrl('https://api.surveymonkey.net/v3/surveys/');
	// surveyMonkeySurveysHTTP.addParam(type:"header",name:"Content-Type",value:"application/json");
	// surveyMonkeySurveysHTTP.addParam(type:"header",name:"Authorization",value:"#authKey#");
	// surveyMonkeySurveysHTTP.addParam(type:"url",name:"api_key",value:"#apiKey#");
	// surveyMonkeySurveysHTTP.addParam(type:"body",value:"{}");

	// result = surveyMonkeySurveysHTTP.send().getPrefix();
	// content = result.FileContent;

	// surveys = DeserializeJSON(content);

	// writeDump(surveys); //will output all surveys with thier IDs, set it above on line 2

	/*
		Fetch the survey details
	*/

	surveyQuestionDetails = new http();
	surveyQuestionDetails.setMethod("GET");
	surveyQuestionDetails.setUrl('https://api.surveymonkey.net/v3/surveys/#satifactionSurveyID#/details');
	surveyQuestionDetails.addParam(type:"header",name:"Content-Type",value:"application/json");
	surveyQuestionDetails.addParam(type:"header",name:"Authorization",value:"#authKey#");
	surveyQuestionDetails.addParam(type:"url",name:"api_key",value:"#apiKey#");

	resultDetails = surveyQuestionDetails.send().getPrefix();
	contentDetails = resultDetails.FileContent;

	//filewrite('satifactionSurveyDetails.json',contentDetails);
	//contentDetails = fileread('satifactionSurveyDetails.json');

	satifactionSurveyDetails = DeserializeJSON(contentDetails);

	/*
		Fetch the responses to the survey
	*/

	surveyMonkeySatisfactionSurveysHTTP = new http();
	surveyMonkeySatisfactionSurveysHTTP.setMethod("GET");
	surveyMonkeySatisfactionSurveysHTTP.setUrl('https://api.surveymonkey.net/v3/surveys/#satifactionSurveyID#/responses/bulk');
	surveyMonkeySatisfactionSurveysHTTP.addParam(type:"header",name:"Content-Type",value:"application/json");
	surveyMonkeySatisfactionSurveysHTTP.addParam(type:"header",name:"Authorization",value:"#authKey#");
	surveyMonkeySatisfactionSurveysHTTP.addParam(type:"url",name:"api_key",value:"#apiKey#");
	surveyMonkeySatisfactionSurveysHTTP.addParam(type:"url",name:"per_page",value:"100");
	surveyMonkeySatisfactionSurveysHTTP.addParam(type:"url",name:"start_created_at",value:surveyQueryTime);

	result = surveyMonkeySatisfactionSurveysHTTP.send().getPrefix();
	content = result.FileContent;

	//filewrite('satifactionSurveyResults.json',content);
	//content = fileread('satifactionSurveyResults.json');

	satifactionSurveyResults = DeserializeJSON(content);

	resultsArray = []; //build array of responses for later looping

	for ( surveyResponse in satifactionSurveyResults.data ){
		//Formats the date coming back from Survey Monkey
		thisCreateDate = listGetAt(surveyResponse.date_created, 1, 'T')
			& ' '
			& listGetAt( listGetAt(surveyResponse.date_created, 2, 'T'), 1, '+' );
		noOfQuestions = 0; //Counts questions on each survey, this varies due to Yes/No questions
		//Loops over each survey response
		for ( page in surveyResponse.pages ){ //Loops over pages in survey
			pageTitle = getPageTitle( page.id, satifactionSurveyDetails.pages );
			for ( question in page.questions ){ //Loops over Questions on page
				questionHeading = getQuestionHeading(
						question.id,
						page.id,
						satifactionSurveyDetails.pages
					);
				for ( answer in question.answers ){ //Loops over answers on a page
					if ( structKeyExists(answer,'row_id') ){
						rowId = answer.row_id;
						rowText = getRowText(
							answer.row_id,
							question.id,
							page.id,
							satifactionSurveyDetails.pages
						);
					} else {
						rowId = 0; //sets to 0 (zero) if no rows appears on page
						rowText = '';
					}
					if ( structKeyExists(answer,'text') ){ //Fetch the text for responses that are text entry
						answerText = answer.text;
						answerWeight = 9999; //No weight. Giving it max weight for reporing
					} else if ( structKeyExists(answer,'choice_id') ) { //Fetches data for the choice choosen by user
						answerData = getChoiceText(
								answer.choice_id,
								question.id,
								page.id,
								satifactionSurveyDetails.pages
							);
						answerText = answerData.text;
						answerWeight = answerData.weight; //Weight of answer, 9999 is non weighted question
					}
					noOfQuestions++; //incements the number of questions per response
					response = { //builds the final structure of data for each response
						'01_pageTitle': pageTitle,
						'02_questionHeading': questionHeading,
						'03_rowText': rowText,
						'04_answerText': answerText,
						'05_answerWeight' : val( answerWeight ),
						'06_responseId': surveyResponse.id,
						'07_responseTime': thisCreateDate,
						'08_surveyId': surveyResponse.survey_id,
						'09_questionId': question.id,
						'10_questionNo': val( noOfQuestions )
					}
					arrayAppend(resultsArray, response); //Adds to final array
				}

			}

		}
	}

	public any function getPageTitle(pageId, surveyPages) {
		//writeDump(arguments);
		for ( var page in arguments.surveyPages ){
			if ( page.id == arguments.pageId ){
				return page.title;
			}
		}
	}

	public any function getQuestionHeading(questionId, pageId, surveyPages) {
		//writeDump(arguments);
		for ( var page in arguments.surveyPages ){
			if ( page.id == arguments.pageId ){
				for ( var question in page.questions ){
					//Loops over question in Survey
					if ( question.id == arguments.questionId ){
						return question.headings[1].heading;//Returns first element in headings
					}
				}

			}
		}
	}

	public any function getRowText(rowId, questionId, pageId, surveyPages) {
		//writeDump(arguments);
		for ( var page in arguments.surveyPages ){
			if ( page.id == arguments.pageId ){
				for ( var question in page.questions ){
					//Loops over question in Survey
					if ( question.id == arguments.questionId ){
						if ( structKeyExists(question,'answers') ){
							for ( var row in question.answers.rows ){
								//Loops over rows of questions
								if ( row.id == arguments.rowId ){
									return row.text;
								}
							}
						}
					}
				}

			}
		}
	}

	public any function getChoiceText(choiceId, questionId, pageId, surveyPages) {
		//writeDump(arguments);
		for ( var page in arguments.surveyPages ){
			if ( page.id == arguments.pageId ){
				for ( var question in page.questions ){
					//Loops over question in Survey
					if ( question.id == arguments.questionId ){
						if ( structKeyExists(question,'answers') ){
							for ( var choice in question.answers.choices ){
								//Loops of choices for questions
								if ( choice.id == arguments.choiceId ){
									return {text: choice.text, weight: ( structkeyexists(choice,'weight') ? choice.weight : 9999 ) };
								}
							}
						}
					}
				}

			}
		}
	}

	//writeDump(resultsArray);
</cfscript>

<cfloop array="#resultsArray#" index="result" >
	<cfif devMode >
		<cfoutput>
			<h3>Dev Mode - Would insert this record</h3>
			pageTitle - #left( result.01_pageTitle, 255 )# <br>
			,questionHeading - #left( result.02_questionHeading, 255 )# <br>
			,rowText - #left( result.03_rowText, 255 )# <br>
			,answerText - #left( result.04_answerText, 1000 )# <br>
			,answerWeight - #result.05_answerWeight# <br>
			,responseId - #result.06_responseId# <br>
			,responseTime - #result.07_responseTime# <br>
			,surveyId - #result.08_surveyId# <br>
			,questionId - #result.09_questionId# <br>
			,questionNo - #result.10_questionNo# <br>
			<hr>
		</cfoutput>
	<cfelse>
		<cfquery datasource="emsapps" name="qryFindMaxTimeStamp">
			INSERT INTO
				dbo.surveryMonkey
				(
					pageTitle
					,questionHeading
					,rowText
					,answerText
					,answerWeight
					,responseId
					,responseTime
					,surveyId
					,questionId
					,questionNo
				)
			VALUES
				(
					<cfqueryparam value="#left( result.01_pageTitle, 255 )#" cfsqltype="cf_sql_varchar" maxlength="255" >
					,<cfqueryparam value="#left( result.02_questionHeading, 255 )#" cfsqltype="cf_sql_varchar" maxlength="255" >
					,<cfqueryparam value="#left( result.03_rowText, 255 )#" cfsqltype="cf_sql_varchar" maxlength="255" >
					,<cfqueryparam value="#left( result.04_answerText, 1000 )#" cfsqltype="cf_sql_varchar" maxlength="1000" >
					,<cfqueryparam value="#result.05_answerWeight#" cfsqltype="cf_sql_integer" >
					,<cfqueryparam value="#result.06_responseId#" cfsqltype="cf_sql_bigint" >
					,<cfqueryparam value="#result.07_responseTime#" cfsqltype="cf_sql_timestamp" >
					,<cfqueryparam value="#result.08_surveyId#" cfsqltype="cf_sql_bigint" >
					,<cfqueryparam value="#result.09_questionId#" cfsqltype="cf_sql_bigint" >
					,<cfqueryparam value="#result.10_questionNo#" cfsqltype="cf_sql_integer" >
				)
		</cfquery>
	</cfif>
</cfloop>