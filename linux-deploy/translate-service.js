#!/usr/bin/env node

import 'dotenv/config'
import Fastify from 'fastify'
import { 
  handleTranslateRequest, 
  getApiDoc, 
  logger
} from 'google-translate-universal'

// ========== 应用配置 ==========
const config = {
  port: process.env.PORT || 3000,
  host: process.env.HOST || '::',  // 默认使用IPv6双栈模式
  accessToken: process.env.ACCESS_TOKEN || '',
  nodeEnv: process.env.NODE_ENV || 'production'
}

// ========== 创建应用 ==========
const fastify = Fastify({
  logger: {
    level: 'info',
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: false,
        translateTime: 'yyyy-mm-dd HH:MM:ss Z',
        ignore: 'pid,hostname,reqId,req,res,responseTime',
        destination: './logs/translate-service.log',
        mkdir: true
      }
    }
  }
})

// ========== 日志处理 ==========
const logHandler = (level, ...args) => {
  const message = args.join(' ')
  
  if (fastify.log[level]) {
    fastify.log[level](message)
  } else {
    fastify.log.info(message)
  }
}

logger.on(logHandler)

// ========== 优雅退出 ==========
const gracefulShutdown = (signal) => {
  fastify.log.info(`收到${signal}信号，正在优雅退出...`)
  
  fastify.close(() => {
    logger.off(logHandler)
    process.exit(0)
  })
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))
process.on('exit', () => {
  logger.off(logHandler)
})

// ========== 中间件注册 ==========
// CORS
await fastify.register(import('@fastify/cors'), {
  origin: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
})

// ========== 路由定义 ==========
// 根路径 - API文档
fastify.get('/', async (request, reply) => {
  return getApiDoc('Google 翻译服务', '1.0.2')
})

// 健康检查
fastify.get('/health', async (request, reply) => {
  const uptime = process.uptime()
  const memory = process.memoryUsage()
  
  // 计算运行时间
  const days = Math.floor(uptime / (24 * 60 * 60))
  const hours = Math.floor((uptime % (24 * 60 * 60)) / (60 * 60))
  const minutes = Math.floor((uptime % (60 * 60)) / 60)
  const seconds = Math.floor(uptime % 60)
  
  // 转换内存单位为MB
  const formatMemory = (bytes) => (bytes / 1024 / 1024).toFixed(2)
  
  return {
    status: "ok",
    timestamp: new Date().toISOString(),
    service: "Google Translate Service",
    version: "1.0.2",
    environment: config.nodeEnv,
    uptime: `服务已运行 ${days}天 ${hours}时 ${minutes}分 ${seconds}秒`,
    memory: {
      rss: `进程占用的物理内存是 ${formatMemory(memory.rss)}MB`,
      heapTotal: `堆总内存是 ${formatMemory(memory.heapTotal)}MB`,
      heapUsed: `堆已使用内存是 ${formatMemory(memory.heapUsed)}MB`,
      external: `外部内存是 ${formatMemory(memory.external)}MB`,
      arrayBuffers: `数组缓冲区是 ${formatMemory(memory.arrayBuffers)}MB`
    }
  }
})

// 翻译接口
fastify.route({
  method: ['GET', 'POST'],
  url: '/translate',
  handler: async (request, reply) => {
    let params = {}
    
    if (request.method === 'GET') {
      const { text, source_lang, target_lang, token } = request.query
      params = { text, source_lang, target_lang, token }
    } else {
      const { text, source_lang, target_lang } = request.body
      params = {
        text,
        source_lang,
        target_lang,
        token: request.query.token
      }
    }
    
    const headers = request.method === 'POST' ? 
      { authorization: request.headers.authorization } : {}
    
    const result = await handleTranslateRequest(
      params, 
      headers, 
      config.accessToken, 
      { verbose: true }
    )
    
    reply.status(result.code === 200 ? 200 : 500)
    return result
  }
})

// ========== 错误处理 ==========
fastify.setErrorHandler((error, request, reply) => {
  fastify.log.error(`请求错误: ${error.message}`)
  
  reply.status(500).send({
    code: 500,
    message: '服务器内部错误',
    error: config.nodeEnv === 'development' ? error.message : undefined
  })
})

fastify.setNotFoundHandler((request, reply) => {
  reply.status(404).send({
    code: 404,
    message: '接口不存在',
    path: request.url
  })
})

// ========== 启动服务 ==========
const start = async () => {
  try {
    await fastify.listen({ 
      port: config.port, 
      host: config.host 
    })
    
    // 构造正确的访问地址
    const getDisplayUrl = (host, port) => {
      if (host === '::') {
        // IPv6 双栈模式 - 显示本地访问地址
        return `http://127.0.0.1:${port}`
      } else if (host === '0.0.0.0') {
        // IPv4 全局模式 - 显示本地访问地址
        return `http://127.0.0.1:${port}`
      } else {
        // 具体地址
        return `http://${host}:${port}`
      }
    }
    
    const displayUrl = getDisplayUrl(config.host, config.port)
    
    const startupInfo = [
      `🚀 Google翻译服务已启动`,
      `📡 监听地址: ${config.host}:${config.port}`,
      `🌐 本地访问: ${displayUrl}`,
      `🏥 健康检查: ${displayUrl}/health`,
      `📖 API文档: ${displayUrl}/`,
      `🔧 环境: ${config.nodeEnv}`,
      `📊 进程ID: ${process.pid}`
    ]
    
    // 根据监听模式显示外部访问提示
    if (config.host === '::') {
      startupInfo.push(`🌍 外部访问: http://服务器IP:${config.port} (IPv4) 或 http://[服务器IPv6]:${config.port} (IPv6)`)
    } else if (config.host === '0.0.0.0') {
      startupInfo.push(`🌍 外部访问: http://服务器IP:${config.port}`)
    }
    
    startupInfo.push(`💡 提示: 请将'服务器IP'替换为您的实际服务器IP地址`)
    
    startupInfo.forEach(info => {
      fastify.log.info(info)
    })
    
  } catch (err) {
    const errorMsg = `启动失败: ${err.message}`
    fastify.log.error(errorMsg)
    process.exit(1)
  }
}

start()