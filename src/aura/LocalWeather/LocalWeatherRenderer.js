({
    rerender: function(cmp, helper) {
        console.log('rerender'); 
        return this.superRerender()
    },
})