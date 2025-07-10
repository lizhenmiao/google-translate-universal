# Google 翻译通用库

一个完全框架无关的 Google 翻译 API 封装库，可以与任何 Web 框架无缝集成。

## ✨ 特点

- 🌍 **完全通用**: 不依赖任何特定框架，任何框架都能直接使用
- 🔧 **纯函数设计**: 核心功能为纯函数，易于测试和维护
- 🎯 **TypeScript**: 完整的 TypeScript 支持
- 🚀 **零适配器**: 无需为每个框架编写适配器
- 📦 **零依赖**: 核心功能无外部依赖
- 🛡️ **错误处理**: 完善的错误处理和重试机制
- 📝 **日志监听**: 支持自定义日志处理和监听

## 📦 安装

```bash
npm install google-translate-universal
```

## 🐧 Linux 一键部署

如果你想在 Linux 服务器上快速部署翻译服务，可以使用我们提供的一键安装脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/lizhenmiao/google-translate-universal/master/linux-deploy/install.sh | sudo bash
```

详细说明请查看：[Linux 部署指南](./linux-deploy/INSTALL_GUIDE.md)

### 📁 目录说明

- **`/linux-deploy/`** - Linux 服务器一键部署相关文件
  - `install.sh` - 交互式安装管理脚本
  - `translate-service.js` - Fastify 生产环境服务
  - `INSTALL_GUIDE.md` - 详细安装使用指南

## 🚀 快速开始

### 1. 纯函数使用（推荐）

```typescript
import { translate } from 'google-translate-universal'

// 最简单的翻译
const result = await translate('Hello World', {
  from: 'en',
  to: 'zh'
})
console.log(result.text) // 你好世界
```

### 2. 通用处理器使用

适用于任何框架，只需要传入参数对象：

```typescript
import { handleTranslateRequest } from 'google-translate-universal'

// 任何框架都可以这样使用
const params = { text: 'Hello', source_lang: 'en', target_lang: 'zh' }
const headers = { authorization: 'Bearer token' } // 可选
const response = await handleTranslateRequest(params, headers)
```

### 3. 日志监听功能

监听所有日志输出，便于调试和记录：

```typescript
import { logger, translate } from 'google-translate-universal'

// 基础日志监听
logger.on((level, ...args) => {
  console.log(`[${level.toUpperCase()}]`, ...args)
})

// 现在所有翻译过程中的日志都会被捕获
const result = await translate('Hello', { 
  from: 'en', 
  to: 'zh', 
  verbose: true // 启用详细日志
})
```

**高级日志处理示例：**

```typescript
// 根据日志级别处理不同的日志
logger.on((level, ...args) => {
  const timestamp = new Date().toISOString()
  const message = args.join(' ')
  
  switch (level) {
    case 'error':
      console.error(`🚨 [${timestamp}] [ERROR]`, message)
      break
    case 'warn':
      console.warn(`⚠️  [${timestamp}] [WARN]`, message)
      break
    case 'info':
      console.info(`ℹ️  [${timestamp}] [INFO]`, message)
      break
  }
})
```

**Logger 方法说明：**

```typescript
// 日志监听器管理
logger.on(callback)              // 添加日志监听器
logger.off(callback)             // 移除指定监听器
logger.removeAllListeners()      // 清除所有监听器
logger.listenerCount()           // 获取当前监听器数量

// 手动发送日志
logger.info('这是一条信息')
logger.warn('这是一条警告')
logger.error('这是一条错误')
```

**防止内存泄漏（可选）：**

```typescript
// 保存监听器引用，方便后续清理
const logHandler = (level, ...args) => {
  console.log(`[翻译] [${level}]`, ...args)
}

logger.on(logHandler)

// 使用完毕后清理
logger.off(logHandler)

// 或者程序退出时清理所有监听器
process.on('exit', () => {
  logger.removeAllListeners()
})
```

**日志监听示例输出：**
```
[INFO] 开始翻译: en -> zh, 文本长度: 5
[INFO] 生成了 20 个配置
[INFO] 尝试配置 1/20: translate-pa.googleapis.com
[INFO] 翻译成功! 使用配置: translate-pa.googleapis.com
```

## 🔧 框架集成示例

### Hono

```typescript
import { Hono } from 'hono'
import { 
  handleTranslateRequest, 
  getCorsHeaders, 
  getApiDoc, 
  getHealthCheck,
  logger
} from 'google-translate-universal'

const app = new Hono()
const ACCESS_TOKEN = process.env.ACCESS_TOKEN

// 设置日志监听（可选）
const logHandler = (level, ...args) => {
  console.log(`[翻译日志] [${level.toUpperCase()}]`, ...args)
}
logger.on(logHandler)

// 程序退出时清理日志监听器
process.on('exit', () => {
  logger.off(logHandler)
})

// CORS 中间件
app.use('*', async (c, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    c.header(key, value)
  })
  
  if (!['GET', 'POST'].includes(c.req.method)) {
    return c.text('Method Not Allowed', 405)
  }
  await next()
})

// API 文档
app.get('/', (c) => {
  const apiDoc = getApiDoc('Google 翻译服务 - Hono版本', '1.0.0')
  return c.json(apiDoc)
})

// 健康检查
app.get('/health', (c) => {
  const health = getHealthCheck('Google Translate Service (Hono)')
  return c.json(health)
})

// 翻译接口
app.all('/translate', async (c) => {
  let params = {}
  
  if (c.req.method === 'GET') {
    // GET 请求：所有参数包括 token 都从 query 获取
    params = {
      text: c.req.query('text'),
      source_lang: c.req.query('source_lang'),
      target_lang: c.req.query('target_lang'),
      token: c.req.query('token')
    }
  } else if (c.req.method === 'POST') {
    // POST 请求：业务参数从 body 获取，token 从 query 获取
    const { text, source_lang, target_lang } = await c.req.json()

    params = {
      text,
      source_lang,
      target_lang,
      token: c.req.query('token')  // POST 的 token 也从 query 获取
    }
  }
  
  const headers = c.req.method === 'POST' ? { authorization: c.req.header('Authorization') } : {}
  const result = await handleTranslateRequest(params, headers, ACCESS_TOKEN, { verbose: true })

  return c.json(result, result.code === 200 ? 200 : 500)
})

export default app
```

### Express

```typescript
import express from 'express'
import { 
  handleTranslateRequest, 
  getCorsHeaders, 
  getApiDoc, 
  getHealthCheck,
  logger
} from 'google-translate-universal'

const app = express()
const ACCESS_TOKEN = process.env.ACCESS_TOKEN

// 设置日志监听（可选）
const logHandler = (level, ...args) => {
  console.log(`[翻译日志] [${level.toUpperCase()}]`, ...args)
}
logger.on(logHandler)

// 程序退出时清理日志监听器
process.on('exit', () => {
  logger.off(logHandler)
})

app.use(express.json())

// CORS 中间件
app.use((req, res, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    res.header(key, value)
  })
  
  if (!['GET', 'POST'].includes(req.method)) {
    return res.status(405).send('Method Not Allowed')
  }
  next()
})

// API 文档
app.get('/', (req, res) => {
  const apiDoc = getApiDoc('Google 翻译服务 - Express版本', '1.0.0')
  return res.json(apiDoc)
})

// 健康检查
app.get('/health', (req, res) => {
  const health = getHealthCheck('Google Translate Service (Express)')
  return res.json(health)
})

// 翻译接口
app.all('/translate', async (req, res) => {
  let params = {}
  
  if (req.method === 'GET') {
    // GET 请求：所有参数包括 token 都从 query 获取
    const { text, source_lang, target_lang, token } = req.query

    params = {
      text,
      source_lang,
      target_lang,
      token
    }
  } else if (req.method === 'POST') {
    // POST 请求：业务参数从 body 获取，token 从 query 获取
    const { text, source_lang, target_lang } = req.body

    params = {
      text,
      source_lang,
      target_lang,
      token: req.query.token  // POST 的 token 也从 query 获取
    }
  }
  
  const headers = req.method === 'POST' ? { authorization: req.headers.authorization } : {}
  const result = await handleTranslateRequest(params, headers, ACCESS_TOKEN, { verbose: true })
  
  return res.status(result.code === 200 ? 200 : 500).json(result)
})

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`Server running on port ${port}`)
})
```

### Koa

```typescript
import Koa from 'koa'
import Router from '@koa/router'
import bodyParser from 'koa-bodyparser'
import { 
  handleTranslateRequest, 
  getCorsHeaders, 
  getApiDoc, 
  getHealthCheck,
  logger
} from 'google-translate-universal'

const app = new Koa()
const router = new Router()
const ACCESS_TOKEN = process.env.ACCESS_TOKEN

// 设置日志监听（可选）
const logHandler = (level, ...args) => {
  console.log(`[翻译日志] [${level.toUpperCase()}]`, ...args)
}
logger.on(logHandler)

// 程序退出时清理日志监听器
process.on('exit', () => {
  logger.off(logHandler)
})

app.use(bodyParser())

// CORS 中间件
app.use(async (ctx, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    ctx.set(key, value)
  })
  
  if (!['GET', 'POST'].includes(ctx.method)) {
    ctx.status = 405
    ctx.body = 'Method Not Allowed'
    return
  }
  await next()
})

// API 文档
router.get('/', (ctx) => {
  const apiDoc = getApiDoc('Google 翻译服务 - Koa版本', '1.0.0')
  ctx.body = apiDoc
})

// 健康检查
router.get('/health', (ctx) => {
  const health = getHealthCheck('Google Translate Service (Koa)')
  ctx.body = health
})

// 翻译接口
router.all('/translate', async (ctx) => {
  let params = {}
  
  if (ctx.method === 'GET') {
    // GET 请求：所有参数包括 token 都从 query 获取
    const { text, source_lang, target_lang, token } = ctx.query

    params = {
      text,
      source_lang,
      target_lang,
      token
    }
  } else if (ctx.method === 'POST') {
    // POST 请求：业务参数从 body 获取，token 从 query 获取
    const { text, source_lang, target_lang } = ctx.request.body

    params = {
      text,
      source_lang,
      target_lang,
      token: ctx.query.token  // POST 的 token 也从 query 获取
    }
  }
  
  const headers = ctx.method === 'POST' ? { authorization: ctx.headers.authorization } : {}
  const result = await handleTranslateRequest(params, headers, ACCESS_TOKEN, { verbose: true })
  
  ctx.status = result.code === 200 ? 200 : 500
  ctx.body = result
})

app.use(router.routes())
app.use(router.allowedMethods())

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`Server running on port ${port}`)
})
```

### Fastify

```typescript
import Fastify from 'fastify'
import { 
  handleTranslateRequest, 
  getCorsHeaders, 
  getApiDoc, 
  getHealthCheck,
  logger
} from 'google-translate-universal'

const fastify = Fastify({ logger: true })
const ACCESS_TOKEN = process.env.ACCESS_TOKEN

// 设置日志监听（可选）
const logHandler = (level, ...args) => {
  // 使用 fastify 原生日志系统，性能更好且支持结构化日志
  if (fastify.log[level]) {
    fastify.log[level]('[翻译日志]', ...args)
  } else {
    // 如果日志级别不存在，回退到 info 级别
    fastify.log.info(`[翻译日志] [${level.toUpperCase()}]`, ...args)
  }
}
logger.on(logHandler)

// 程序退出时清理日志监听器
process.on('exit', () => {
  logger.off(logHandler)
})

// CORS 插件
await fastify.register(import('@fastify/cors'), {
  origin: true,
  methods: ['GET', 'POST']
})

// API 文档
fastify.get('/', async (request, reply) => {
  const apiDoc = getApiDoc('Google 翻译服务 - Fastify版本', '1.0.0')
  return apiDoc
})

// 健康检查
fastify.get('/health', async (request, reply) => {
  const health = getHealthCheck('Google Translate Service (Fastify)')
  return health
})

// 翻译接口
fastify.route({
  method: ['GET', 'POST'],
  url: '/translate',
  handler: async (request, reply) => {
    let params = {}
    
    if (request.method === 'GET') {
      // GET 请求：所有参数包括 token 都从 query 获取
      const { text, source_lang, target_lang, token } = request.query

      params = {
        text,
        source_lang,
        target_lang,
        token
      }
    } else if (request.method === 'POST') {
      // POST 请求：业务参数从 body 获取，token 从 query 获取
      const { text, source_lang, target_lang } = request.body

      params = {
        text,
        source_lang,
        target_lang,
        token: request.query.token  // POST 的 token 也从 query 获取
      }
    }
    
    const headers = request.method === 'POST' ? { authorization: request.headers.authorization } : {}
    const result = await handleTranslateRequest(params, headers, ACCESS_TOKEN, { verbose: true })
    
    reply.status(result.code === 200 ? 200 : 500)
    return result
  }
})

const start = async () => {
  try {
    await fastify.listen({ port: 3000 })
    console.log('Server running on port 3000')
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()
```

### 任意其他框架

只要能提取出参数和请求头，就能使用：

```typescript
// 伪代码 - 适用于任何框架
async function handleRequest(request) {
  // 1. 提取参数（来自 query 或 body）
  const params = extractParams(request)
  
  // 2. 提取请求头
  const headers = extractHeaders(request)
  
  // 3. 调用通用处理器
  const result = await handleTranslateRequest(params, headers)
  
  // 4. 返回响应
  return createResponse(result)
}
```

## 📚 API 参考

### 核心函数

#### `translate(text, options)`

翻译文本的核心函数。

**参数:**
- `text: string` - 要翻译的文本
- `options: TranslateOptions` - 翻译选项

**返回值:** `Promise<TranslateResult>`

```typescript
interface TranslateOptions {
  from?: string          // 源语言 (默认: 'auto')
  to: string            // 目标语言 (必需)
  verbose?: boolean     // 启用详细日志
  preferredConfig?: Partial<TranslateConfig>
  randomizeAll?: boolean
}

interface TranslateResult {
  text: string          // 翻译后的文本
  sourceLang: string    // 检测到的源语言
  targetLang: string    // 目标语言
}
```

#### `handleTranslateRequest(params, headers?, accessToken?, options?)`

处理翻译请求的通用函数，适用于任何框架。

**参数:**
- `params: RequestParams` - 请求参数对象
- `headers?: RequestHeaders` - 请求头对象（可选）
- `accessToken?: string` - 访问令牌（可选）
- `options?: object` - 附加选项

**返回值:** `Promise<TranslateResponse>`

```typescript
interface RequestParams {
  text?: string
  source_lang?: string
  target_lang?: string
  token?: string
}

interface RequestHeaders {
  authorization?: string
  Authorization?: string
}

interface TranslateResponse {
  code: number
  data?: string           // 翻译结果
  source_lang?: string
  target_lang?: string
  message?: string        // 错误信息（如果有）
  id?: number
  method?: string
}
```

### 工具函数

#### `getCorsHeaders()`

返回 CORS 头配置对象。

```typescript
const corsHeaders = getCorsHeaders()
// 返回: { 'Access-Control-Allow-Origin': '*', ... }
```

#### `getApiDoc(description?, version?)`

返回 API 文档对象。

#### `getHealthCheck(serviceName?)`

返回健康检查响应对象。

#### `logger`

日志对象，支持监听所有日志输出。

```typescript
// 监听所有日志
logger.on((level: string, ...args: any[]) => {
  console.log(`[${level}]`, ...args)
})

// 手动发送日志
logger.info('这是一条信息')
logger.warn('这是一条警告')
logger.error('这是一条错误')
```

## 💡 使用场景

### 1. 快速集成到现有项目

```typescript
// 在现有的路由处理中直接使用
app.post('/api/translate', async (req, res) => {
  const result = await handleTranslateRequest(req.body)
  res.json(result)
})
```

### 2. 批量翻译

```typescript
const texts = ['Hello', 'World', 'How are you?']
const results = await Promise.all(
  texts.map(text => translate(text, { from: 'en', to: 'zh' }))
)
```

### 3. 自定义错误处理

```typescript
try {
  const result = await translate('Hello', { from: 'en', to: 'zh' })
  console.log(result.text)
} catch (error) {
  console.error('翻译失败:', error.message)
}
```

### 4. 带身份验证的使用

```typescript
// 使用 token 参数验证
const params = { 
  text: 'Hello', 
  source_lang: 'en', 
  target_lang: 'zh',
  token: 'your-access-token'
}

// 或使用 Authorization 头验证
const headers = { 
  authorization: 'Bearer your-access-token' 
}

const result = await handleTranslateRequest(params, headers, 'your-access-token')
```


#### Logger 类新增方法：

```typescript
// 日志监听器管理
logger.on(callback)              // 添加日志监听器
logger.off(callback)             // 移除指定监听器
logger.removeAllListeners()      // 清除所有监听器
logger.listenerCount()           // 获取当前监听器数量

// 日志发送方法
logger.info('信息日志')           // 发送 info 级别日志
logger.warn('警告日志')           // 发送 warn 级别日志
logger.error('错误日志')          // 发送 error 级别日志
```

#### 防止内存泄漏的最佳实践：

```typescript
// 方法1：单个监听器清理
const logHandler = (level, ...args) => {
  console.log(`[${level}]`, ...args);
};

logger.on(logHandler);
// 使用完后清理
logger.off(logHandler);

// 方法2：程序退出时清理所有监听器
process.on('exit', () => {
  logger.removeAllListeners();
});

// 方法3：检查监听器数量，避免重复添加
if (logger.listenerCount() === 0) {
  logger.on(myHandler);
}
```

**完整日志输出示例：**
```
开始翻译...
ℹ️  开始翻译: en -> zh, 文本长度: 11
ℹ️  生成了 20 个配置
ℹ️  尝试配置 1/20: translate-pa.googleapis.com
ℹ️  翻译成功! 使用配置: translate-pa.googleapis.com
翻译完成: 你好世界
```

## 🏆 优势

1. **真正的通用性**: 不需要为每个框架写适配器
2. **简单易用**: 只需要传入参数对象即可
3. **类型安全**: 完整的 TypeScript 支持
4. **灵活性**: 既可以用纯函数，也可以用处理器
5. **可扩展**: 易于添加新功能和自定义逻辑
6. **零依赖**: 不会增加项目负担
7. **日志监听**: 完整的日志监听和处理能力

## 📝 许可证

MIT License