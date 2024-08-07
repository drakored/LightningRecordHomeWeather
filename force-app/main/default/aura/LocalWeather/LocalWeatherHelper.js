({
    getLocalWeather: function(component, recID) {
        var spinner = component.find('spinner');
        $A.util.removeClass(spinner, "slds-hide");
        
        if (recID) {
            var action = component.get("c.getLocalWeatherByRecord");
            action.setParams({
                "recordId": recID
            });
        }
        action.setCallback(this, function(response) {
            this.doLayout(response, component);
        });
        $A.enqueueAction(action);
    },
    doLayout: function(response, component) {
        var spinner = component.find('spinner');
        var data = JSON.parse(response.getReturnValue());
        var warning = component.find('warning');
        
        if (data) {
            $A.util.addClass(warning, 'slds-hide');
            // for testing diff temps
            //data['feelsLikeF'] = '900';
            component.set("v.weather", data);
            console.log("weather data: ", data);
        } else {
            component.set("v.errorMessage", 'No weather received');            
            $A.util.removeClass(warning, 'slds-hide');
        }
        
        $A.util.addClass(spinner, "slds-hide");
    }
})