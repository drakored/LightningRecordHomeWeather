// built onto Mike Katulka's Lab Coat post https://gist.github.com/LabCoatTeam/92fd5ddf8e1da9a47057/#file-integration_basicauthrestcallout-cls
// http://www.crmscience.com/single-post/2016/04/15/Apex-for-REST-Integration-Overview-of-the-Callout
public class WeatherUtil {
    // signup for a key at https://www.wunderground.com/weather/api/d/pricing.html (or use a free dev one)
    private static final String API_KEY = '[YOUR_KEY_HERE]';
    
    // example endpoint
    //http://api.wunderground.com/api/[KEY]/conditions/q/CA/San_Francisco.json
    
    // a wrapper class to hold the weather in the format we want
    public class Weather {
        public String imageUrl { get; set; }        // image.url
        public String imageTitle { get; set; }      // image.title
        public String imageLink { get; set; }       // image.link
        
        public String displayLocation { get; set; } // display_location.full
        
        public String observationTime { get; set; } // observation_time
        public String currentWeather { get; set; }  // weather
        public String currentTempF { get; set; }    // temp_f
        public String currentTempC { get; set; }    // temp_c
        public String currentWind { get; set; }     // wind_string
        public String feelsLikeF { get; set; }      // feelslike_f
        public String feelsLikeC { get; set; }      // feelslike_c
        
        public String weatherIconUrl { get; set; }  // icon_url
    }
    
    // this method is to be used in Lightning Components (record based view)
    @AuraEnabled
    public static String getLocalWeatherByRecord(Id recordId) {
        WeatherUtil.Weather weather = new WeatherUtil.Weather();
        String state = '';
        String cityName = '';
        String result = '';
        
        // compare the sobject type of the record Id to account
        if (recordId.getSobjectType() == Account.SObjectType) {
            Account a = [SELECT ShippingState, ShippingCity FROM Account WHERE Id = :recordId];
            state = a.ShippingState;
            cityName = a.ShippingCity;
        } else throw new System.SObjectException('Local weather not built for this SObject');
        
        // make the callout if we have a valid city and state
        if (String.isNotBlank(state) && String.isNotBlank(cityName)) {
            result = makeCallout(state,cityName,weather);
        }

        // return the serialized weather wrapper class, or null
        return result.equalsIgnoreCase('success!') ? JSON.serialize(weather) : null;
    }
    
    // this method is to be used in Lightning Components (non record based view)
    @AuraEnabled
    public static String getLocalWeather(String state, String cityName) {
        WeatherUtil.Weather weather = new WeatherUtil.Weather();
        String result = makeCallout(state,cityName,weather);
        
        // return the serialized weather wrapper class, or null
        return result.equalsIgnoreCase('success!') ? JSON.serialize(weather) : null;
    }
    
    // Method to perform callouts
    public static String makeCallout(String state, String cityName, WeatherUtil.Weather weather){
        
        // define a response to caller
        String outcomeMsg;
        
        // define basic information for later, store these in a protected custom setting
        String endpoint = 'http://api.wunderground.com'; // be sure this is configured in "Remote Site Settings"
        String resource = '/api/' + API_KEY + '/conditions/q/' + state + '/' + cityName.replace(' ', '_') + '.json';
        String method = 'GET';  
        
        // check to ensure a callout can be performed using the Limits class. 
        // This is 100 callouts per execution as of Spring 16 release
        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
            outcomeMsg = 'Maximum number of callouts has been reached.';
            
            // configure and perform the callout
        } else {
            
            // define transaction variables
            HttpRequest req = new HttpRequest();
            HttpResponse res = new HttpResponse();
            Http h = new Http();
            
            // Configure the request
            req.setEndpoint(endpoint + resource);
            req.setMethod(method);
            req.setTimeout(120000);
            
            
            // Configure standard headers
            req.setHeader('Accept', '*/*');

            // This tells the API that we are sending and receiving the data as a JSON object 
            req.setHeader('Content-Type', 'application/json');

            // Additional headers may be needed / Refer to the API documentation. 
            // Use a service like runscope.com to test everything ahead of time.
            
            // Set the body json with the description parameter, basically a string with a key value pair construction.
            // This will look very different for each integration resource.  
            // Some APIs don't use a body to take the request, 
            // they may simply take additional resources "/resource/order/Ord#" in the URI 
            // or parameters "resource/?orderId=133" in the URI

            // this integration doesn't require this, however yours might so I've left this here as an example
            //req.setBody('{"text" : "' + description + '"}');
            
            // Attempt the callout - create return error on exception
            try {
                
                // Perform callout and set response
                res = h.send(req);
                
                // check response 
                if ((res.getStatusCode() == 200 || res.getStatusCode() == 201) && res.getBody() != null && res.getBody() != null) {
                    
                    // Deserialize the response untyped
                    Map<String, Object> untypedMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                    System.debug('@@@');
                    System.debug(res.getBody());
                    // Check success of deserialization
                    if (untypedMap.containsKey('current_observation')) {
                        // The deserialized response contains the expected key!
                        outcomeMsg = 'Success!';
                        
                        Map<String,Object> currentWeather = (Map<String,Object>)untypedMap.get('current_observation');
                        
                        
                        if (currentWeather.containsKey('image')) {
                            Map<String,Object> image = (Map<String,Object>)currentWeather.get('image');
                            
                            weather.imageUrl = (String)image.get('url');                                                // image.url
                            weather.imageTitle = (String)image.get('title');                                            // image.title
                            weather.imageLink = (String)image.get('link');                                              // image.link
                        }

                        if (currentWeather.containsKey('display_location')) {
                            Map<String,Object> displayLocation = (Map<String,Object>)currentWeather.get('display_location');
                            
                            weather.displayLocation = (String)displayLocation.get('full');                              // display_location.full
                        }

                        weather.observationTime = (String)currentWeather.get('observation_time');                       // observation_time
                        weather.currentWeather = (String)currentWeather.get('weather');                                 // weather
                        weather.currentWind = (String)currentWeather.get('wind_string');                                // wind_string
                        
                        // round the temperatures before storing them
                        Decimal tempF = (Decimal)currentWeather.get('temp_f');
                        weather.currentTempF = String.valueOf(tempF.round());                                           // temp_f
                        
                        Decimal tempC = (Decimal)currentWeather.get('temp_c');
                        weather.currentTempC = String.valueOf(tempC.round());                                           // temp_c
                        
                        Decimal feelsLikeF = Decimal.valueOf((String)currentWeather.get('feelslike_f'));
                        weather.feelsLikeF = String.valueOf(feelsLikeF.round());                                        // feelslike_f
                        
                        Decimal feelsLikeC = Decimal.valueOf((String)currentWeather.get('feelslike_c'));
                        weather.feelsLikeC = String.valueOf(feelsLikeC.round());                                        // feelslike_c

                        weather.weatherIconUrl = (String)currentWeather.get('icon_url');                                // icon_url
                                
                                
                    } else if (untypedMap.containsKey('response') && ((Map<String,Object>)(untypedMap.get('response'))).containsKey('results')) {
                        // do something with search results
                    } else {
                        outcomeMsg = 'Error: Verify key not found in response';
                    }
                } else {
                    // callout failed
                    outcomeMsg = 'Error: Callout failed. Please review the debug log for additional details.';
                }
                
            } catch (DMLexception e) {
                // Unexpected exceptions will be caught here, like a deserialization error.
                outcomeMsg = 'Error: An exception has been encountered while calling out to Integration:  ' + e.getMessage();
            }
        }
        
        // Return the response
        return outcomeMsg;
    }
}