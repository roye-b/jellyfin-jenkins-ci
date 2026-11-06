const config = require('./webpack.prod.js');

config.cache = {
    type: 'filesystem',
    cacheDirectory: process.env.WORKSPACE + '/.webpack-cache',
    buildDependencies: {
        config: [
            __filename,
            require.resolve('./webpack.prod.js'),
            require.resolve('./webpack.common.js')
        ]
    }
};

module.exports = config;
