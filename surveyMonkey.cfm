<cfscript>
	satifactionSurveyID = 69797272;
	narrativeQuestion = 8; //The narrative is question 8 on the response back from survey monkey

	include "apiKeys.cfm";

	surveyHoursBack = 72; //number of hours to go back in history to pull responses from. Set this the same at your Scheduled task interval

	currentUTCTime = DateConvert("local2Utc", now());
	surveyQueryTime = dateAdd('h',-surveyHoursBack, currentUTCTime);
	surveyQueryTime = dateFormat(surveyQueryTime, "YYYY-MM-DDT") & timeFormat(surveyQueryTime, "HH:MM:ss");

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

	writeDump(satifactionSurveyDetails, false);
	writeDump(satifactionSurveyResults, false);

	resultsArray = [];

	for ( surveyResponse in satifactionSurveyResults.data ){
		//Loops over each survey response
		for ( page in surveyResponse.pages ){
			//Loops over pages in survey
			pageTitle = getPageTitle( page.id, satifactionSurveyDetails.pages );
			for ( question in page.questions ){
				//Loops over Questions on page
				questionHeading = getQuestionHeading(
						question.id,
						page.id,
						satifactionSurveyDetails.pages
					);
				for ( answer in question.answers ){
					if ( structKeyExists(answer,'row_id') ){
						rowId = answer.row_id;
						rowText = getRowText(
							answer.row_id,
							question.id,
							page.id,
							satifactionSurveyDetails.pages
						);
					} else {
						rowId = 0;
						rowText = '';
					}
					if ( structKeyExists(answer,'text') ){
						answerText = answer.text;
					} else if ( structKeyExists(answer,'choice_id') ) {
						answerText = answer.choice_id;
					}
					response = {
						'responseId': surveyResponse.id,
						'responseTime': surveyResponse.date_created,
						'surveyId': surveyResponse.survey_id,
						'pageTitle': pageTitle,
						'questionHeading': questionHeading,
						'pageAndQuestion': page.id & ',' & question.id,
						'answerText': answerText,
						'rowId': rowId,
						'rowText': rowText
					}
					arrayAppend(resultsArray, response);
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

	writeDump(resultsArray);
</cfscript>