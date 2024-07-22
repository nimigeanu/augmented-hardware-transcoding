module.exports = {
  apps: [
    {
      name: 'transcode',
      script: '/opt/transcode/index.js',
      watch: true,
      env: {
        NODE_ENV: 'development',
      },
      env_production: {
        NODE_ENV: 'production',
      },
    },
  ],
};
