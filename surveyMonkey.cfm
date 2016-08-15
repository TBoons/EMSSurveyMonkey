<cfscript>
	satifactionSurveyID = 69797272;
	narrativeQuestion = 8; //The narrative is question 8 on the response back from survey monkey

	include "apiKeys.cfm";

	surveyHoursBack = 24; //number of hours to go back in history to pull responses from. Set this the same at your Scheduled task interval

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

	satifactionSurveyDetails = DeserializeJSON(contentDetails);
	writeDump(satifactionSurveyDetails);

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

	satifactionSurveyResults = DeserializeJSON(content);
	writeDump(satifactionSurveyResults);
	resultsArray = [];
	for ( i = 1; i <= arrayLen(satifactionSurveyResults.data); i++ ){
		//Each Response
		for ( ii = 1; ii <= arrayLen(satifactionSurveyResults.data[i].pages); ii++ ){
			//Each Page
			for ( iii = 1; iii <= arrayLen(satifactionSurveyResults.data[i].pages[ii].questions); iii++ ){
				//Each Question
				questionId = satifactionSurveyResults.data[i].pages[ii].questions[iii].id;
				questionAnswerDetails = {
					'responseId': satifactionSurveyResults.data[i].id,
					'questionId': questionId,
					'questionText': getQuestionText(
						ii,
						questionId,
						satifactionSurveyDetails
					 )
				}
				if ( structKeyExists(satifactionSurveyResults.data[i].pages[ii].questions[iii].answers[1],'choice_id') ){
					answerId = satifactionSurveyResults.data[i].pages[ii].questions[iii].answers[1];
					answerText = '';
				} else {
					answerText = satifactionSurveyResults.data[i].pages[ii].questions[iii].answers[1].text;
				}

				arrayAppend(resultsArray, questionAnswerDetails);
			}
		}
	}

	writeDump(resultsArray);

public any function getQuestionText(page, questionId, surveyDetails) {
	var rtnText = 'NotFound';
	for ( var f = 1; f <= arrayLen(arguments.surveyDetails.pages[arguments.page].questions); f++ ){
		if ( arguments.surveyDetails.pages[arguments.page].questions[f].id == arguments.questionId ){
			//Found Question
			rtnText = arguments.surveyDetails.pages[arguments.page].questions[f].headings[1].heading;
		}
	}

	return rtnText;
}

abort;

	// surveyDetailsHTTP = new http();
	// surveyDetailsHTTP.setMethod("GET");
	// surveyDetailsHTTP.addParam(type:"header",name:"Content-Type",value:"application/json");
	// surveyDetailsHTTP.addParam(type:"header",name:"Authorization",value:"#authKey#");
	// surveyDetailsHTTP.addParam(type:"url",name:"api_key",value:"#apiKey#");

	// resultsArray = [];
	// resultCompiled = {};

	// for ( i = 1; i <= arrayLen(satifactionSurveyResults.data); i++ ){
	// 	//writeDump(satifactionSurveyResults.data[i]);
	// 	surveyDetailsHTTP.setUrl('https://api.surveymonkey.net/v3/surveys/#satifactionSurveyID#/responses/#satifactionSurveyResults.data[i].id#/details');
	// 	detailsResult = surveyDetailsHTTP.send().getPrefix();
	// 	detailsContent = detailsResult.FileContent;
	// 	writeDump( DeserializeJSON( detailsContent ) );
	// }

	// for ( i = 1; i <= arrayLen(satifactionSurveyResults.data); i++ ){
	// }



	// for ( i = 1; i <= arrayLen(satifactionSurveyResults.data); i++ ){ //Loops over each response

	// 	if ( arrayLen(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions) ){ //Determines if Question is answered
	// 		for ( ii = 1; ii <= arrayLen(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[1].answers); ii++ ){ //quesion was answered
	// 			resultCompiled = {
	// 				name:"",
	// 				phone:"",
	// 				email:"",
	// 				comment:"",
	// 				id:satifactionSurveyResults.data[i].id,
	// 				date:satifactionSurveyResults.data[i].date_created
	// 			};
	// 			for ( iii = 1; iii <= arrayLen(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions); iii++ ){ //Phone, Name, Email, Comment answer loops
	// 				for ( iiii = 1; iiii <= arrayLen(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers); iiii++ ){
	// 					if ( structKeyExists(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii],'row_id') ){
	// 						switch(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii].row_id){
	// 							case 9457876478: //name field
	// 								resultCompiled.comment = satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii].text;
	// 							break;
	// 							case 9457876486: //email field
	// 								resultCompiled.email = satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii].text;
	// 							break;
	// 							case 9457876487: //phone field
	// 								resultCompiled.phone = satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii].text;
	// 							break;

	// 							default:
	// 								//Not a field we are parsing. Ignore.
	// 							break;
	// 						}

	// 					} else {
	// 						//The Comments section is missing a row_id, if statement determines if this is the comments answer
	// 						if ( !structKeyExists(satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii],'row_id') ){
	// 							resultCompiled.comment = satifactionSurveyResults.data[i].pages[narrativeQuestion].questions[iii].answers[iiii].text;
	// 						}

	// 					}
	// 				}
	// 			}
	// 		}
	// 		arrayAppend(resultsArray, resultCompiled);
	// 	}
	// }
</cfscript>

<cfloop array="#resultsArray#" index="r" >
	<cfoutput>
		<p>Name: <!--- #r.name# ---></p>
		<p>Email: <!--- #r.email# ---></p>
		<p>Phone: <!--- #r.phone# ---></p>
		<p>Comment: #r.comment#</p>
		<p>id: #r.id#</p>
	</cfoutput>
	<hr>
</cfloop>

