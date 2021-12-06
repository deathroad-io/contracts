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
    },
    getRouter: function (chainId) {
        if (chainId == 56) {
            return "0x10ED43C718714eb63d5aA57B78B54704E256024E"
        } else if (chainId == 97) {
            return "0x3380ae82e39e42ca34ebed69af67faa0683bb5c1" //ape swap testnet
        }
        throw "unsupported chain Id"
    },
    getPairedToken: function(chainId) {
        if (chainId == 56) {
            return "0xe9e7cea3dedca5984780bafc599bd69add087d56" //busd on mainnet
        }
        return "0x4fb99590ca95fc3255d9fa66a1ca46c43c34b09a" //banana on bsc testnet
    },
    getDAOPaymentToken: function(chainId) {
        if (chainId == 56) {
            return "0xe9e7cea3dedca5984780bafc599bd69add087d56" //busd on mainnet
        }
        return "0x82CFC816E3f777fc4F1557Bb861D49e17ebD603C" //drace on bsc testnet
    }
}