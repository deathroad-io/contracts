module.exports = {
    getApprover: function(chainId) {
        if (chainId == 56) {
            return "0xb3a8dbdb5c3955ee22bc218e1115ab928c291a93"
        } 
        return "0x75785F9CE180C951c8178BABadFE904ec883D820"
    },
    getSettler: function(chainId) {
        if (chainId == 56) {
            return "0x9ac88880da68a8b18da02b3d2ab95d2a06a1b9c2"
        }
        return "0xd0e3376e1c3af2c11730aa4e89be839d4a1bd761"
    }
}