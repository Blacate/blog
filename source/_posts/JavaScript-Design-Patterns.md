---
title: JavaScript设计模式
date: 2019-01-12 15:08:04
tags: 
  - JavaScript
  - Design-Patterns
categories: JavaScript
---

前几天把《JavaScript设计模式与开发实践》啃完了，整理顺便复习一下～

<!-- more -->

### 单例模式

> 保证一个类只有一个实例，并提供一个访问它的全局访问点。

```javascript
class Singleton {
  constructor(name) {
    this.name = name
    this.instance = null
  }

  getName() {
    return this.name
  }

  static getInstance(name) {
    if (!this.instance) {
      this.instance = new Singleton(name)
    }
    return this.instance
  }
}

const instanceA = Singleton.getInstance('nameA')
const instanceB = Singleton.getInstance('nameB')
console.log(instanceA === instanceB, instanceA.getName(), instanceB.getName())
// true 'nameA' 'nameA'
```

当第一次调用`Singleton.getInstance()`方法的时候，会通过类`Singleton`创建一个对象并缓存给`this.instance`；第二次调用时，就直接返回了上次缓存的对象。所以`instanceA`和`instanceB`是完全相等的，或者可以说两个变量的引用指向同一个地址。第二次调用时，传入的参数`nameB`其实是没用的。

### 策略模式

> 定义一系列的算法，把它们一个个封装起来，并且使它们可以相互替换。

```javascript
// 年终奖计算策略，根据考评等级，分别为4倍，3倍，2倍薪水
const strategies = {
  S(salary) {
    return salary * 4
  },
  B(salary) {
    return salary * 3
  },
  A(salary) {
    return salary * 2
  },
}

/**
 * 根据考评等级计算年终奖
 * @param {string} level 考评等级
 * @param {number} salary 薪水
 */
const calculateBonus = (level, salary) => strategies[level](salary)

console.log(calculateBonus('S', 10000)) // 40000
console.log(calculateBonus('A', 10000)) // 20000
```

定义了三个年终奖计算策略，在计算年终奖函数中，根据考评的等级，将请求委托给策略对象中的某一个进行计算。

### 代理模式

> 为一个对象提供一个代用品或占位符，一遍控制对它的访问。

#### 常见代理模式

+ 保护代理：代理帮被本地过滤掉一些请求。
+ 虚拟代理：使用接口和本体一致的代理，在处理完一定流程后，由代理请求本体的接口。
+ 缓存代理：将运算结果缓存，如果下次运算时，如果传入参数一致，则直接返回缓存的结果。

#### 虚拟代理示例

```vue
<template>
  <img :src="url" :alt="alt" :title="title">
</template>

<script>
export default {
  name: 'VueDefaultImg'
  props: {
    src: String,
    alt: String,
    title: String
  },
  data () {
    return {
      url: ''
    }
  },
  created () {
    const defaultImg = require('./default_image.png')
    this.url = defaultImg
    if (this.src) {
      this.loadImg(this.src)
    }
  },
  methods: {
    loadImg (src) {
      let testImg = new Image()
      testImg.src = src
      testImg.onload = () => {
        this.url = src
      }
    }
  },
  watch: {
    src: function (val, oldVal) {
      this.loadImg(val)
    }
  }
}
</script>
```

这是一个实现vue默认图片的组件，它与`img`标签都对外暴露了`src`,`alt`,`title`三个属性，事实上这个组件代理了`img`标签设置src的方法。在默认情况下，使用的是默认图片，只有当设置的src参数有效时，才去设置真正的`img`标签。

### 迭代器模式

> 提供一种方法顺序访问一个聚合对象中的各个元素，而又不需要暴露该对象的内部表示。

#### 内部迭代器

已经定义号迭代规则，它完全接受整个迭代过程

```javascript
const each = (arr, callback) => {
  for (let i = 0; i < arr.length; i++) {
    callback.call(arr[i], i, arr[i])
  }
}

each([1, 2, 3], (index, element) => console.log(index, element))
```

JavaScript中已经内置了迭代器，比方说`Array.prototype.forEach`，`for...in...`，`for...of...`

#### 外部迭代器

必须显式地请求迭代下一个元素。

```javascript
const Iterator = (obj) => {
  let current = 0
  const next = () => {
    current += 1
  }
  const isDone = () => current >= obj.length
  const getCurrItem = () => obj[current]
  return {
    next,
    isDone,
    getCurrItem,
  }
}

const compare = (iterator1, iterator2) => {
  while (!iterator1.isDone() && !iterator2.isDone()) {
    if (iterator1.getCurrItem() !== iterator2.getCurrItem()) {
      return false
    }
    iterator1.next()
    iterator2.next()
  }
  // 最后需要判断下长度是否相等
  return iterator1.isDone() === iterator2.isDone()
}

const iterator1 = Iterator([1, 2, 3])
const iterator2 = Iterator([1, 2, 3])
console.log(compare(iterator1, iterator2)) // true

// 踩坑，一开始拿iterator比较了三次 发现有问题，因为经过第一次比较后，isDone()已经为true了
const iterator3 = Iterator([1, 2, 3])
const iterator4 = Iterator([1, 2])
console.log(compare(iterator3, iterator4)) // false

const iterator5 = Iterator([1, 2, 3])
const iterator6 = Iterator([1, 2, 4])
console.log(compare(iterator5, iterator6)) // false
```

类似JavaScript中的生成器，参考[generator function](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Statements/function*)

### 发布-订阅模式

> 又叫观察者模式，它定义对象间的一种一对多的依赖关系，当一个对象的状态发生改变时，所有依赖于它的对象都将得到通知。

```javascript
const EventsCenter = (function generateCenter() {
  const keyList = {}
  const listen = (key, callback) => {
    if (!keyList[key]) {
      keyList[key] = []
    }
    keyList[key].push(callback)
  }
  const trigger = (key, ...rest) => {
    const callbacks = keyList[key]
    if (!callbacks || callbacks.length === 0) {
      return false
    }
    callbacks.forEach((callback) => {
      callback(rest)
    })
    return true
  }
  const remove = (key, callback) => {
    const callbacks = keyList[key]
    if (!callbacks) {
      return false
    }
    if (!callback) {
      // 如果没传指定函数进来，则清除所有的函数
      callbacks && (callbacks.length = 0)
      return true
    }
    // 从后往前删除，确保每个都被删除掉
    for (let i = callbacks.length - 1; i >= 0; i--) {
      if (callbacks[i] === callback) {
        callbacks.splice(i, 1)
      }
    }
    return true
  }
  return {
    listen,
    trigger,
    remove,
  }
}())

const testcallback = (info) => {
  console.log(`test event ${info}`)
}

EventsCenter.listen('testevent', testcallback)
EventsCenter.trigger('testevent', 'test-info') // test event test-info

EventsCenter.remove('testevent', testcallback)
EventsCenter.trigger('testevent', 'test-info-after-remove') // nothing
```

### 命令模式

> 将方法的调用,请求或者操作封装到一个单独的对象中,给我们酌情执行同时参数化和传递方法调用的能力。

```javascript
const Car = {
  A() {
    console.log('左转')
  },
  W() {
    console.log('前进')
  },
  D() {
    console.log('右转')
  },
  S() {
    console.log('后退')
  },
}

const makeCommand = (receiver, state) => {
  return () => {
    receiver[state]()
  }
}

const commandStack = [] // 保存命令的堆栈

const pressKey = (key) => {
  const command = makeCommand(Car, key)
  command()
  commandStack.push(command)
}

const reply = () => {
  while (commandStack.length) {
    const command = commandStack.shift()
    command()
  }
}

pressKey('W') // 前进
pressKey('W') // 前进
pressKey('A') // 左转
pressKey('D') // 右转
pressKey('S') // 后退

reply() // 前进 前进 左转 右转 后退
```

### 组合模式

> 将对象组合成树形结构以表示“部分-整体”的层次结构，组合模式使得用户对单个对象和组合对象的使用具有一致性。

```javascript
const MacroCommand = () => {
  const commandList = []
  const add = (command) => {
    commandList.push(command)
  }
  const execute = () => {
    commandList.forEach((command) => {
      command.execute()
    })
  }
  return {
    add,
    execute,
  }
}

// 打开空调命令
const openAcCommand = {
  execute() {
    console.log('打开空调')
  },
}

// 打开电视和音响命令,由打开媒体命令控制
const openTvCommand = {
  execute() {
    console.log('打开电视')
  },
}
const openSoundCommand = {
  execute() {
    console.log('打开音箱')
  },
}
const openMediaCommand = MacroCommand()
openMediaCommand.add(openTvCommand)
openMediaCommand.add(openSoundCommand)

// 回家后需要执行的总命令
const AfterGoHomeCommand = MacroCommand()
AfterGoHomeCommand.add(openAcCommand)
AfterGoHomeCommand.add(openMediaCommand)

AfterGoHomeCommand.execute() // 打开空调 打开电视 打开音箱
```

### 模板方法模式

> 模板方法模式由两部分结构组成，第一部分是抽象父类，第二部分是具体的实现子类。

```javascript
class Beverage {
  boilWater() {
    console.log('把水煮沸')
  }

  brew() {
    throw new Error('子类必须重写brew方法')
  }

  pourInCup() {
    throw new Error('子类必须重写pourInCup方法')
  }

  addCondiments() {
    throw new Error('子类必须重写addCondiments方法')
  }

  init() {
    this.boilWater()
    this.brew()
    this.pourInCup()
    this.addCondiments()
  }
}

class Coffee extends Beverage {
  brew() {
    console.log('用沸水冲泡咖啡')
  }

  pourInCup() {
    console.log('把咖啡倒进杯子')
  }

  addCondiments() {
    console.log('加糖和牛奶')
  }
}

class Tea extends Beverage {
  brew() {
    console.log('用沸水浸泡茶叶')
  }

  pourInCup() {
    console.log('把茶倒进杯子')
  }

  addCondiments() {
    console.log('加柠檬')
  }
}

const tea = new Tea()
const coffee = new Coffee()

tea.init()
coffee.init()

```

### 享元模式

```javascript
class Model {
  constructor(sex) {
    this.sex = sex
  }

  takePhoto(underwear) {
    console.log(`sex = ${this.sex}; underwear = ${underwear}`)
  }
}

const maleModel = new Model('male')
const femaleModel = new Model('female')

for (let i = 1; i <= 50; i++) {
  maleModel.takePhoto(i)
}

for (let j = 1; j <= 50; j++) {
  femaleModel.takePhoto(j)
}
```

### 职责链模式

> 使多个对象都有机会处理请求，从而避免请求的发送者和接受者之间的耦合关系，将这些对象练成一条链，并沿着这条链传递该请求，直到有一个对象处理它为止。

```javascript
const order500 = (orderType, pay, stock) => {
  if (orderType === 1 && pay === true) {
    console.log('500元定金预购，得到100优惠券')
  } else {
    return 'nextSuccessor'
  }
}

const order200 = (orderType, pay, stock) => {
  if (orderType === 2 && pay === true) {
    console.log('200元定金预购，得到50优惠券')
  } else {
    return 'nextSuccessor'
  }
}

const orderNormal = (orderType, pay, stock) => {
  if (stock > 0) {
    console.log('普通购买，无优惠券')
  } else {
    console.log('手机库存不足')
  }
}

Function.prototype.after = function(fn) {
  const self = this
  return function () {
    const ret = self.apply(this, arguments)
    if (ret === 'nextSuccessor') {
      return fn.apply(this, arguments)
    }
    return ret
  }
}

const order = order500.after(order200).after(orderNormal)

order(1, true, 500) // 500元定金预购，得到100优惠券
order(2, true, 500) // 200元定金预购，得到50优惠券
order(1, false, 500) // 普通购买，无优惠券
```

### 中介者模式

> 用一个中介对象来封装一系列的对象交互，中介者使各对象不需要显式地相互饮用，从而使其耦合松散，而且可以独立地改变它们之间的交互。

```javascript
const playerDirector = (function generateDirector() {
  const players = {}
  const operations = {}

  operations.addPlayer = (player) => {
    const { teamColor } = player
    players[teamColor] = players[teamColor] || []
    players[teamColor].push(player)
  }

  operations.removePlayer = (player) => {
    const { teamColor } = player
    const teamPlayers = players[teamColor] || []
    for (let i = teamPlayers.length - 1; i >= 0; i--) {
      if (teamPlayers[i] === player) {
        teamPlayers.splice(i, 1)
      }
    }
    // teamPlayers = teamPlayers.filter(item => item !== player)
  }

  operations.changeTeam = (player, newTeamColor) => {
    operations.removePlayer(player)
    player.teamColor = newTeamColor
    operations.addPlayer(player)
  }

  operations.playerDead = (player) => {
    const { teamColor } = player
    const teamPlayers = players[teamColor]

    let allDead = true

    for (let i = 0; i < teamPlayers.length; i++) {
      if (teamPlayers[i].state !== 'dead') {
        allDead = false
        break
      }
    }

    if (allDead) {
      teamPlayers.forEach((element) => {
        element.lose()
      })
      const colors = Object.keys(players)
      colors.forEach((color) => {
        if (color !== teamColor) {
          players[color].forEach((element) => {
            element.win()
          })
        }
      })
    }
  }

  const reciveMessage = (message, ...rest) => {
    operations[message].apply(this, rest)
  }

  return {
    reciveMessage,
  }
}())

class Player {
  constructor(name, teamColor) {
    this.name = name
    this.teamColor = teamColor
    this.state = 'alive'
    playerDirector.reciveMessage('addPlayer', this)
  }

  win() {
    console.log(`${this.name} won`)
  }

  lose() {
    console.log(`${this.name} lost`)
  }

  die() {
    this.state = 'dead'
    playerDirector.reciveMessage('playerDead', this)
  }

  remove() {
    playerDirector.reciveMessage('removePlayer', this)
  }

  changeTeam(color) {
    playerDirector.reciveMessage('changeTeam', this, color)
  }
}

const player1 = new Player('皮蛋', 'red')
const player2 = new Player('小怪', 'red')
const player3 = new Player('宝宝', 'red')
const player4 = new Player('小强', 'blue')
const player5 = new Player('葱头', 'blue')
const player6 = new Player('海盗', 'blue')

player1.remove()
player2.remove()
player4.changeTeam('red')
player3.die()
player4.die()
```

### 装饰者模式

> 给给对象动态地增加职责的方式叫做装饰者模式。

```javascript
Function.prototype.before = function before(beforefn) {
  const self = this
  return function () {
    beforefn.apply(this, arguments)
    return self.apply(this,arguments)
  }
}

Function.prototype.after = function after(afterfn) {
  const self = this
  return function () {
    const ret = self.apply(this, arguments)
    afterfn.apply(this, arguments)
    return ret
  }
}

let testfn = () => {
  console.log('function itself')
}

testfn = testfn.before(() => {
  console.log('before function')
}).after(() => {
  console.log('after function')
})

testfn()
```

### 状态模式

> 允许一个对象在其内部改变状态时改变它的行为，对象看起来似乎修改了它的类。

```javascript
class OffLightState {
  constructor(light) {
    this.light = light
  }

  buttonWasPressed() {
    console.log('弱光')
    this.light.setState(this.light.weakLightState)
  }
}

class WeakLightState {
  constructor(light) {
    this.light = light
  }

  buttonWasPressed() {
    console.log('强光')
    this.light.setState(this.light.strongLightState)
  }
}

class StrongLightState {
  constructor(light) {
    this.light = light
  }

  buttonWasPressed() {
    console.log('关灯')
    this.light.setState(this.light.offLightState)
  }
}

class Light {
  constructor() {
    this.offLightState = new OffLightState(this)
    this.weakLightState = new WeakLightState(this)
    this.strongLightState = new StrongLightState(this)
    this.currState = this.offLightState
  }

  click() {
    this.currState.buttonWasPressed()
  }

  setState(newState) {
    this.currState = newState
  }
}

const light = new Light()

light.click() // 弱光
light.click() // 强光
light.click() // 关灯
light.click() // 弱光
```

### 适配器模式

> 将一个接口转换成客户希望的另一个接口，适配器模式使接口不兼容的那些类可以一起工作。

```javascript
const googleMap = {
  show() {
    console.log('开始渲染谷歌地图')
  },
}

const baiduMap = {
  display() {
    console.log('开始渲染百度地图')
  }
}

const baiduMapAdapter = {
  show() {
    baiduMap.display()
  },
}

const renderMap = (map) => {
  map.show()
}

renderMap(googleMap)
renderMap(baiduMapAdapter)
```

### 参考文档

+ [JavaScript设计模式与开发实践](https://book.douban.com/subject/26382780/)
+ [图说设计模式](https://design-patterns.readthedocs.io/zh_CN/latest/index.html)

