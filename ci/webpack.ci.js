
const path = require('path');
const config = require('./webpack.prod.js');

config.cache = {
    type: 'filesystem',
    cacheDirectory: process.env.WEBPACK_CACHE_DIR || path.resolve(__dirname, '.webpack-cache'),
    buildDependencies: {
        config: [
            __filename,
            require.resolve('./webpack.prod.js'),
            require.resolve('./webpack.common.js')
        ]
    }
};

module.exports = config;
