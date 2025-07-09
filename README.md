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

// 高级日志处理
logger.on((level, ...args) => {
  const timestamp = new Date().toISOString()
  const message = args.join(' ')
  
  // 根据级别处理不同日志
  switch (level) {
    case 'error':
      // 发送错误到监控系统
      sendToErrorTracking({ level, message, timestamp })
      break
    case 'warn':
      // 记录警告日志
      console.warn(`⚠️  [${timestamp}]`, message)
      break
    case 'info':
      // 记录信息日志（仅在详细模式下）
      if (process.env.VERBOSE) {
        console.info(`ℹ️  [${timestamp}]`, message)
      }
      break
  }
})

// 现在所有翻译过程中的日志都会被捕获
const result = await translate('Hello', { 
  from: 'en', 
  to: 'zh', 
  verbose: true // 启用详细日志
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
logger.on((level, ...args) => {
  console.log(`[${level.toUpperCase()}]`, ...args)
})

// CORS 中间件
app.use('*', async (c, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    c.header(key, value)
  })
  
  if (c.req.method !== 'GET' && c.req.method !== 'POST') {
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
  const params = c.req.method === 'GET' 
    ? Object.fromEntries(c.req.queries().entries())
    : await c.req.json()
  
  const headers = { authorization: c.req.header('Authorization') }
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
logger.on((level, ...args) => {
  console.log(`[${new Date().toISOString()}] [${level.toUpperCase()}]`, ...args)
})

app.use(express.json())

// CORS 中间件
app.use((req, res, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    res.header(key, value)
  })
  
  if (req.method !== 'GET' && req.method !== 'POST') {
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
  const params = req.method === 'GET' ? req.query : req.body
  const headers = { authorization: req.headers.authorization }
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
logger.on((level, ...args) => {
  console.log(`[${level.toUpperCase()}]`, ...args)
})

app.use(bodyParser())

// CORS 中间件
app.use(async (ctx, next) => {
  const corsHeaders = getCorsHeaders()
  Object.entries(corsHeaders).forEach(([key, value]) => {
    ctx.set(key, value)
  })
  
  if (ctx.method !== 'GET' && ctx.method !== 'POST') {
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
  const params = ctx.method === 'GET' ? ctx.query : ctx.request.body
  const headers = { authorization: ctx.headers.authorization }
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
logger.on((level, ...args) => {
  fastify.log[level](...args)
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
    const params = request.method === 'GET' ? request.query : request.body
    const headers = { authorization: request.headers.authorization }
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

### 5. 集成日志系统

完整的日志系统集成示例：

```typescript
import { logger, translate } from 'google-translate-universal'

// 创建自定义日志处理器
class TranslateLogger {
  constructor() {
    this.setupLogger()
  }

  setupLogger() {
    logger.on((level, ...args) => {
      const timestamp = new Date().toISOString()
      const message = args.join(' ')
      
      // 格式化日志
      const logEntry = {
        timestamp,
        level,
        message,
        service: 'google-translate'
      }
      
      // 发送到不同的日志系统
      switch (level) {
        case 'error':
          this.handleError(logEntry)
          break
        case 'warn':
          this.handleWarning(logEntry)
          break
        case 'info':
          this.handleInfo(logEntry)
          break
      }
    })
  }

  handleError(logEntry) {
    // 发送到错误监控系统（如 Sentry）
    console.error('🚨', logEntry.message)
    // Sentry.captureMessage(logEntry.message, 'error')
  }

  handleWarning(logEntry) {
    // 发送到日志聚合系统
    console.warn('⚠️ ', logEntry.message)
    // logAggregator.send(logEntry)
  }

  handleInfo(logEntry) {
    // 仅在开发环境输出
    if (process.env.NODE_ENV === 'development') {
      console.info('ℹ️ ', logEntry.message)
    }
    // 发送到分析系统
    // analytics.track('translate_info', logEntry)
  }
}

// 初始化日志系统
const translateLogger = new TranslateLogger()

// 使用翻译功能，所有日志都会被自动捕获和处理
async function translateWithLogging(text, options) {
  try {
    console.log('开始翻译...')
    const result = await translate(text, { ...options, verbose: true })
    console.log('翻译完成:', result.text)
    return result
  } catch (error) {
    console.error('翻译失败:', error.message)
    throw error
  }
}

// 使用示例
translateWithLogging('Hello World', { from: 'en', to: 'zh' })
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