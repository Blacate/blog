---
title: 使用redis有序集合实现定时任务
date: 2018-12-27 14:51:10
tags: 
  - redis
  - timed-task
  - sorted-set
categories: node
---

最近在业务开发的过程中遇到了实现定时任务的需求

**真叫人头大**

<!-- more-->

### 常见方案

+ 使用`node-schedule` 或者`node-cron` 之类的定时任务库
+ 使用时间轮定时器
+ 使用redis的**有序集合**或**键过期通知**实现

#### 定时任务库

个人感觉，`node-schedule`更适合比较固定的定时任务，比方说需要每天凌晨一点备份数据，需要每隔几分钟执行某个操作，而这次的需求是在十五分钟后自动关闭订单，当然也可以创建很多很多的定时任务，或者说每隔一分钟遍历一次数据库，可是这样不是很优雅，而且也不方便以后维护。

#### 时间轮定时器

时间轮定时器可以理解为一个轮盘，每个轮盘上有多个轮槽，我们将需要的task放进合适的轮槽里面，每隔一定的时间间隔，跳到下一个轮槽中，同时触发轮槽中的task。优点是时间间隔可控，且效率较高；但是task都是保存在内存中的，重启服务时会导致task的丢失，同时在多实例的情况下，每个实例都维护了自己的时间轮，不方便管理。

#### redis键过期通知

redis有一种键空间通知的机制，客户端可以订阅一些key的事件，包括key过期事件，但是我们不能得到过期的key所对应的value值，所以需要把相关的信息都保存在key中，比方所需要在15分中后触发关闭订单的操作，可以设置key为`CheckOrder-${order_id}`并且设置它在15分钟后过期，这样在15分钟后，我们会收到此key过期的通知时间，再根据`order_id`去数据库中获取订单的详情，并进行接下来的操作。

#### redis有序集合

在有序集合中，将任务计划执行的时间戳作为score，这样任务在加入sets的时候已经按时间排序，这时候，我们每隔一段时间去取出符合条件的任务并执行即可。

### 使用redis有序集合实现定时任务

#### 初始化redis客户端

```typescript
// redis.service.ts
import * as redis from 'redis';
import * as bluebird from 'bluebird';

export class RedisService {
    constructor() {
        bluebird.promisifyAll(redis); // 转为promise方法
        this.redis = redis.createClient(); // 初始化客户端
    }
}
```

#### 实现添加任务以及取出任务的方法

```typescript
export class RedisService {
    constructor() {} // ...
    
    public async zadd(key: string, score: number, member: string): Promise<void> {
        await this.redis.zaddAsync(key, score, member);
    }
    
    public async zshift(key: stirng, max_score: number) {
        const taskArr = await this.redis.zrangebyscoreAsync(key, 0, max_score);
        if (taskArr.lenght === 0 ) {
            return null;
        }
        const randomPosition = Math.floor(Math.random() * taskArr.lenght);
        const item = taskArr.splice(randomPosition, 1)[0];
        if (await this.redis.zremAsync(key, item)) {
            return item;
        }
        return null;
    }
}
```

+ `zadd(key, score, value)`方法为向有序集合中添加一条记录
+ `zrangebyscore(key, min, max)`为返回有序集合中`score`介于[min, max]之间的成员，递增排列
+ 因为存在多实例的情况，所以每个实例是随机从任务池中取出一个任务，避免每个实例取的都是同一个
+ 因为redis的原子性，所以在取出任务后，将该任务从有序集合中剔除可以避免同一个任务同时被多个实例同时执行

#### 使用

```typescript
// order.service.ts
import { RedisService} from './redis.service.ts';
import * as schedule from 'node-schedule';

const redisService = new RedisService();

// add task
redisService.zadd('cron_order_task', Date.now() + 15 * 60 * 1000, 'order_id_1');

// handle effective task
const rule = new schedule.RecurrenceRule();
rule.minute = new schedule.Range(0, 59, 1);
schedule.scheduleJob(rule, async () => {
    // get one
    let order_id = await redisService.zshift('cron_order_task', Date.now());
    while (order_id) {
        // handle order by order_id
        // ...
        // get another
        order_id = await redisService.zshift('cron_order_task', Date.now());
    }
})
```

这边使用了`node-schedule`每隔一分钟检查有没有需要执行的任务，对于时间要求更高的任务，可以减少时间间隔或者使用其他的解决方案

### 总结

使用有序集合来实现定时任务实际上是把执行时间作为排序项，每隔一段时间检查是否有到期的任务，适合对于时间误差不是很严格的定时任务，相对于时间轮等方式来讲，有序集合的方式相对来说任务列表更直观，更友好一些。

### REF

+ [node-schedule](https://github.com/node-schedule/node-schedule)
+ [ZRANFEBYSCORE](http://redisdoc.com/sorted_set/zrangebyscore.html)
+ [时间轮定时器](https://www.jianshu.com/p/4c270f81ff22)
+ [redis定时任务](https://blog.csdn.net/orangleliu/article/details/52038092)