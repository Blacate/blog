---
title: 使用nginx部署vue项目
date: 2019-01-26 16:42:55
tags:
  - vue
  - nginx
  - subdirectory
  - websocket
categories: vue
---

在使用nginx部署vue项目的时候遇到了一些问题，所以记录一下。

全文总共分成三个部分，包括开发环境以及生成环境：

+ 开发环境中的nginx配置
+ 根目录下的部署
+ 子目录下的部署

<!--more-->

### 开发环境下的nginx配置

一般情况下，我们需要使用nginx代理的场景是需要用指定的域名开发，但是当我们使用`yarn serve`启动一个web server时，如果`host`没有指定的话，会报`Invalid Host`的错误，所以需要先修改`vue-cli`的配置文件。

```javascript
// vue.config.js
module.exports = {
    devServer: {
        port: 9000,  // 不使用默认的8080端口
        public: 'www.example.com', // 指定合法域名
    },
}
```

所以现在需要使用nginx代理`9000`端口，并把`server_name`指向`www.example.com`

```nginx
upstream example_dev {
    keepalive 16;
    server 127.0.0.1:9000;
}

server {
    listen 80;
    server_name www.example.com;
    
    location / {
        proxy_pass  http://example_dev;
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

添加DNS解析记录，这边通过修改hosts的方式

```shell
echo '127.0.0.1 www.example.com' >> /etc/hosts
```

此时，打开浏览器访问`http://www.example.com`就可以正常访问了。

但是打开`DevTools`时却发现websock的连接报错了，这是因为nginx没有代理websocket的请求。

加上对websocket的转发：

```nginx
upstream example_dev {
    keepalive 16;
    server 127.0.0.1:9000;
}

server {
    listen 80;
    server_name dev.example.com;
    
    location / {
        proxy_pass  http://example_dev;
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
    }
}
```

这边需要注意的是`location`和`proxy_pass`的相对路径和绝对路径，因为会影响上游收到请求的路径

可以参考[nginx代理proxy_pass绝对路径和相对路径实验](https://www.jianshu.com/p/b113bd14f584)

**总结：** 核心点在于使用nginx对websock进行代理，坑是`location`匹配和`proxy_pass`的绝对路径和相对路径。

### nginx根目录部署

这可以说是这三个里面最简单的了，因为不需要对websock进行代理，也不需要去修改`vue-cli`的配置文件

```nginx
server {
    listen 80;
    server_name root.example.com;
    
    root /path/to/project/dist;
    index index.html index.htm index;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

如果`vue-router`采用默认的hash模式的话，`try_files`是可有可无的，因为hash虽然会出现在URL中，但是不回被包含在HTTP请求中，对于nginx没有任何的影响，请求的始终是`index.html`文件；但是当使用history模式时，`vue-router`路由的变化会直接影响到nginx的路由匹配，导致404错误，所以需要使用`try_files`来进行内部重定向。

> try_files的作用是按顺序检查文件是否存在，返回第一个找到的文件或文件夹（结尾加斜线表示为文件夹），如果所有的文件或文件夹都找不到，会进行一个内部重定向到最后一个参数。

### nginx子目录部署

这是一个很让人头大的问题，因为需要改动的东西还是蛮多的，而且一不小心就是一个大坑。

主要分成两个部分，一部分是`vue`的配置，一部分是`nginx`的配置。

#### vue部分

`vue`部分的修改分成两个部分：

+ `vue-router`的`base`选项

  ```javascript
  import Router from 'vue-router';
  
  export default new Router({
      mode: 'history',
      base: `${process.env.BASE_URL}/subdir`,
      routes: [
          // ...
      ],
  });
  ```

  参考 [Vue Router 构建选项](https://router.vuejs.org/zh/api/#base)

+ `vue-cli`打包时的`publicPath`

  ```javascript
  module.exports = {
    publicPath: './',
  };
  ```

  因为`publicPath`的默认值时`/`，所以假设项目的URL是`http://sub.example.com/subdir`，此时打包后的html文件是

  ```html
  <!DOCTYPE html>
  <html lang=en>
      <head>
          <meta charset=utf-8>
          <meta http-equiv=X-UA-Compatible content="IE=edge">
          <meta name=viewport content="width=device-width,initial-scale=1">
          <link rel=icon href=/favicon.ico> <title>vue-test-sub-dir</title>
          <link href=/js/about.3bc21d8b.js rel=prefetch>
          <link href=/css/app.c4796643.css rel=preload as=style>
          <link href=/js/app.b000143c.js rel=preload as=script>
          <link href=/js/chunk-vendors.811b44ce.js rel=preload as=script>
          <link href=/css/app.c4796643.css rel=stylesheet>
      </head>
      <body>
          <noscript>
              <strong>We're sorry but vue-test-sub-dir doesn't work properly without JavaScript enabled. Please enable it to continue.</strong>
          </noscript>
          <div id=app></div>
          <script src=/js/chunk-vendors.811b44ce.js> </script> 
          <script src=/js/app.b000143c.js> </script> 
      </body>
  </html>
  
  ```

  可以看到，所有的css文件和js文件都是`/js/xxx.js`的形式，也就是请求`http://sub.example.com/js/xxx.js`，而正确的url是`http://sub.example.com/subdir/js/xxx.js`，一般用`./`来表示相对于`index.html`的相对路径。

  参考 [vue.config.js > pulicPath](https://cli.vuejs.org/config/#publicpath)

#### nginx部分

这部分是有两种解决方案的。一种是以根目录的形式起一个web服务，子目录那边使用`proxy_pass`进行代理；一种是直接在子目录下配置静态文件的访问，关键点是history模式下`try_files`的配置。

+ 代理转发

  ```nginx
  # 以根目录方式单独起一个端口
  server {
      listen 8200;
      
      root /path/to/project/dist;
      index index.html index.htm index;
      
      location / {
          try_files $uri $uri/ /index.html;
      }
  }
  ```

  ```nginx
  # 子目录域名配置文件用proxy_pass进行代理
  server {
      listen 80;
      server_name subs.example.com;
      
      location /subdir/ {
          proxy_pass http://127.0.0.1:8200/;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  
          proxy_http_version 1.1;
          proxy_set_header Connection "";
      }
  }
  ```

  这种个人感觉是一种比较hack的方式，因为它多占用了一个端口，而且也不是很方便维护。

  + 子目录部署

  ```nginx
  server {
      listen 80;
      server_name subs.example.com;
      
      location /sub {
          alias /path/to/project/dist;
          index index.html;
          try_files $uri $uri/ /sub/index.html;
      }
  }
  ```

  这边有两点需要⚠️的：

  + 在`location`里面需要使用`alias`来指定文件夹路径，而不是`root`
  + `try_files` 需要指定子目录`/sub/index.html`

### 参考文档

+ [使用 nginx 部署 HTML5 History 模式的 Vue 项目](http://wall-e.me/%E4%BD%BF%E7%94%A8%20nginx%20%E9%83%A8%E7%BD%B2%20HTML5%20History%20%E6%A8%A1%E5%BC%8F%E7%9A%84%20Vue%20%E9%A1%B9%E7%9B%AE/index.html)
+ [use nginx proxy websock](https://github.com/webpack/webpack-dev-server/issues/763)

