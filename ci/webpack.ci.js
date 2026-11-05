const config = require('./webpack.prod.js');

config.cache = {
    type: 'filesystem',
    cacheDirectory: '/home/jenkins/.cache/jellyfin-webpack',
    buildDependencies: {
        config: [
            __filename,
            require.resolve('./webpack.prod.js'),
            require.resolve('./webpack.common.js')
        ]
    }
};

module.exports = config;
