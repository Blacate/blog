---
title: 使用WebHooks实现自动构建
date: 2018-12-26 01:07:22
tags:
  - webhooks
  - npm
  - git
  - CI
categories: efficiency
---

其实它有个更好听的名字叫做持续集成，不过我觉得还没有到持续集成那么夸张的程度，姑且叫他自动构建吧。

**嗯，它不配。**

<!-- more -->

---

**Update at 20190119**

**Add demo [webhook-service-demo](https://github.com/Blacate/webhook-service-demo)**

---

持续集成大概是我这种懒人的福音吧，毕竟多敲下面几个命令还是挺累的～

```shell
rm -rf dist
npm run build
npm run test
npm publish
```

这个一个npm模块在更新完成之后重新发版需要的步骤，包括：删除旧文件 打包 执行测试脚本 以及最后发布到npm仓库，虽然只有四条命令，但是每次敲一下还是挺麻烦的，而且容易忘，所以写到了`package.json` 中

```json
{
    "scripts": {
        "build": "tsc -p tsconfig.json",
        "format": "lint-staged",
        "prepublish:npm": "rm -rf dist && npm run build",
        "publish:npm": "npm publish",
        "test": "mocha -r ts-node/register test/**/*.spec.ts"
  }
}
```

可是这样一点也不酷，那就试试webhook吧～

### WebHooks?

简单来讲就是我们向远程仓库push代码之后，会给我们指定的URL发送一个POST请求，这样就可以触发我们所需要的操作。

这边以码云为例，每个Hook包括三个方面：

+ URL：POST的地址
+ 密码：每次的请求都会带上密码,用来过滤恶意请求
+ 类型：包括Push，**Tag Push**，Issue，Pull Request，评论

这边用到的是Tag Push，因为需要在每次打版本标签后自动发版



### 处理POST请求

我是用`koa` 单独起了一个服务用来接收并处理POST请求。

```javascript
const Koa = require('koa')
const logger = require('koa-logger')
const bodyParser = require('koa-bodyparser')
const Router = require('koa-router')
const config = require('./config')

// 项目打包脚本
const project1Fun = require('./scripts/project1')

const app = new Koa()
const router = new Router()
const port = config.port || 3000

app.use(logger())
app.use(bodyParser())

router.get('/', async ctx => {
  ctx.status = 204
})

router.post('/project1', async ctx => {
  const body = ctx.request.body
  if (body.password === 'project1password' && body.hook_name === 'tag_push_hooks') {
    project1Fun()
  }
  ctx.body = {
    success: true,
  }
})

app.use(router.routes())
app.use(router.allowedMethods())

app.listen(port, () => {
  console.log(`webhook service start at ${port}`)
})
```

核心的代码其实就一个这个文件，接收请求后判断是否符合条件，如果符合的话，就执行对应的脚本文件。

详细的内容看[Koa官网](https://koajs.com/)即可～



### 脚本文件

这算是自动构建最核心的一部分了，完成了需要我们每次手动执行的发布过程，脚本有两种实现方式：

#### shell脚本

```shell
dir=/tmp/webhook_project1_dir
gitrepo=git@gitee.com:user/project1.git

if [ ! -d dir ]; then
    git clone $gitrepo $dir #如果目录不存在则克隆项目
fi
cd $dir
git reset --hard
git pull #拉取更新
yarn #安装依赖
npm run test #执行测试脚本
npm run publish:npm #发布
```

shell脚本的一个优势是简单，实际就是把命令整理出一个脚本文件；但是，存在的问题就是不可控，我们不能拿到每一步的执行结果，无法控制进度以及做错误通知。

#### JS脚本

```javascript
// scripts/project1.js
const gitP = require('simple-git/promise')
const mkdirp = require('mkdirp')
const Promise = require('bluebird')
const nodeCmd = require('node-cmd')
const print = require('../utils/print') // 打印数组型日志用
const mail = require('../utils/mail') // 封装的邮件服务

const projectDir = '/tmp/webhook_project1_dir'
const gitRepo = 'git@gitee.com:user/project1.git'

const cmd = Promise.promisify(nodeCmd.get, { multiArgs: true, context: nodeCmd })

function initialiseRepo (git) {
  return git.init()
    .then(() => {
      console.log('[INFO] Initing Repo...')
      return git.addRemote('origin', gitRepo)
    })
}

const project1Fun = () => {
  const log = []
  mkdirp.sync(projectDir)
  const git = gitP(projectDir)
  console.log(`[INFO] Repo: ${gitRepo}`)
  git.checkIsRepo()
    .then(isRepo => {
      if (!isRepo) {
        console.log('[INFO] Repo is not exist')
        return initialiseRepo(git)
      }
      console.log('[INFO] Repo is exist.')
      return isRepo
    })
    .then(() => git.reset('hard'))
    .then(() => {
      console.log('[INFO] Pulling updates...')
      return git.pull('origin', 'master')
    })
    .then(() => {
      console.log('[INFO] Installing dependencies...')
      return cmd(`npm install --prefix ${projectDir}`)
    })
    .then(() => {
      console.log('[INFO] Running test scripts...')
      return cmd(`npm run test --prefix ${projectDir}`)
    })
    .then(res => {
      print.printArr(res)
      log.push(...res)
      console.log('[INFO] Publishing package...')
      return cmd(`npm run publish:npm --prefix ${projectDir}`)
    })
    .then(res => {
      print.printArr(res)
      log.push(...res)
      mail.sendMail('i@mymail.com', log, 'Project1 publish success')
    })
    .catch(err => {
      console.log(err)
      log.push(err)
      mail.sendMail('i@mymail.com', log, 'Project1 publish failed')
    })
}

module.exports = project1Fun
```

这里面主要涉及了一下几个部分

##### [node-mkdirp](https://github.com/substack/node-mkdirp)

用来创建文件夹，相当于`mkdir -p` 命令，同时提供了同步的方法

##### [simple-git](https://github.com/steveukx/git-js)

常用git命令的封装，在这次的脚本用用到的是检测是否是个git仓库，clone项目以及拉取更新，项目本身是提供了promise的方法的，方便我们用promise链的形式～

##### [node-cmd](https://github.com/steveukx/git-js)

这个主要是用来执行shell命令，npm上面这类库还是挺多的，试用了好多个，最后发现还是这个最最最合适～

+ 可以使用`bluebird` 实现promise方法
+ 支持`exit code` 的捕获，在异常退出时直接进入`catch` 函数
+ 在promise`resolve` 后可以拿到完整的输出，打印日志方便debug

##### npm prefix

这还算是一个比较重要的部分，因为上面的`node-cmd` 是相对于文件的当前路径来的，所以需要通过`prefix` 将npm命令执行的目录重新指向项目的目录

嗯 先执行 `cd $projectdir` 是没有效果的，不要问我怎么知道的orz

##### 邮件服务

邮件服务是为了通知最后这个脚本执行的结果，包括失败或成功以及相对应的日志信息，方便debug～


### 最后的最后

当这一套都部署完之后，每次需要发版的改动完成之后，只需要执行即可升级到对应的版

```shell
npm version patch #0.0.1的版本变动
npm version minor #0.1.0的版本变动
npm version major #1.0.0的版本变动
```

然后美滋滋的`git push` 之后发现并没有触发webhooks。。

我的天，到底发生了什么？？？ 啊哈，原来是`git` 在push的时候默认不会push新增的tag，所以...

```shell
git config --global push.followTags true
```

酱紫后每次只需要`git push` 之后就可以坐等发布成功的邮件通知啦～

**未知bug：** 偶尔的情况下，码云在`tag push` 后发送POST请求的时候会出现`excution expire`错误，还木有来得及找原因～



### REF

+ [码云WebHooks](https://gitee.com/help/categories/40)
+ [npm prefix](https://codeday.me/bug/20170523/19134.html)
+ [git tag push](https://stackoverflow.com/questions/3745135/push-git-commits-tags-simultaneously)
