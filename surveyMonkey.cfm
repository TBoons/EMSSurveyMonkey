<cfscript>

	/*
		TODO:
			Create DB Tables
			Loop of Array and insert data in to tables
			Find MAX( responseTime ) in DB to populate surveyQueryTime variable to query Suvery Monkey for anything newer than last entered survey
			Write simple page for determining the Survey Monkey Survey ID for use with other surveys
			Uncomment out http requests to fetch live data
	*/

	if ( !structKeyExists(url,'surveyId') ){ //Required URL parameter... Throws error is missing
		throw "Missing url parameter surveyId";
	}
	satifactionSurveyID = url.surveyId; //69797272 is the survey for LCEMS Customer Satifaction Survey

	include "apiKeys.cfm"; //API keys in this cfm file. authKey & apiKey must be set in here

	surveyHoursBack = 72; //number of hours to go back in history to pull responses from. Set this the same at your Scheduled task interval, this can go away once we get MAX from DB

	currentUTCTime = DateConvert("local2Utc", now());
	surveyQueryTime = dateAdd('h',-surveyHoursBack, currentUTCTime);
	surveyQueryTime = dateFormat(surveyQueryTime, "YYYY-MM-DDT") & timeFormat(surveyQueryTime, "HH:MM:ss");

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

	contentDetails = fileread('satifactionSurveyDetails.json');
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

	//result = surveyMonkeySatisfactionSurveysHTTP.send().getPrefix();
	//content = result.FileContent;

	//filewrite('satifactionSurveyResults.json',content);
	content = fileread('satifactionSurveyResults.json');
	satifactionSurveyResults = DeserializeJSON(content);

	//writeDump(satifactionSurveyDetails, true);
	//writeDump(satifactionSurveyResults, true);

	resultsArray = []; //build array of responses for later looping

	for ( surveyResponse in satifactionSurveyResults.data ){
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
				for ( answer in question.answers ){//Loops over answers on a page
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
						answerWeight = 99999; //No weight. Giving it max weight for reporing
					} else if ( structKeyExists(answer,'choice_id') ) { //Fetches data for the choice choosen by user
						answerData = getChoiceText(
								answer.choice_id,
								question.id,
								page.id,
								satifactionSurveyDetails.pages
							);
						answerText = answerData.text;
						answerWeight = answerData.weight; //Weight of answer, 99999 is non weighted question
					}
					noOfQuestions++; //incements the number of questions per response
					response = { //builds the final structure of data for each response
						'01_pageTitle': pageTitle,
						'02_questionHeading': questionHeading,
						'03_rowText': rowText,
						'04_answerText': answerText,
						'05_answerWeight' : val( answerWeight ),
						'06_responseId': surveyResponse.id,
						'07_responseTime': surveyResponse.date_created,
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
									return {text: choice.text, weight: ( structkeyexists(choice,'weight') ? choice.weight : 99999 ) };
								}
							}
						}
					}
				}

			}
		}
	}

	writeDump(resultsArray);
</cfscript>