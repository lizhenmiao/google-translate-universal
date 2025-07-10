#!/usr/bin/env node

import 'dotenv/config'
import Fastify from 'fastify'
import { createWriteStream, existsSync, mkdirSync, readdirSync, unlinkSync } from 'fs'
import { join } from 'path'
import { 
  handleTranslateRequest, 
  getApiDoc, 
  getHealthCheck,
  logger
} from 'google-translate-universal'

// ========== 日志管理器 ==========
class DailyLogger {
  constructor(logDir = './logs', maxFiles = 30) {
    this.logDir = logDir
    this.maxFiles = maxFiles
    this.currentDate = null
    this.logStream = null
    this.ensureLogDir()
    this.setupRotation()
  }

  ensureLogDir() {
    if (!existsSync(this.logDir)) {
      mkdirSync(this.logDir, { recursive: true })
    }
  }

  getLogFileName(date = new Date()) {
    const dateStr = date.toISOString().split('T')[0]
    return join(this.logDir, `translate-service-${dateStr}.log`)
  }

  setupRotation() {
    this.rotateIfNeeded()
    setInterval(() => this.rotateIfNeeded(), 60000) // 每分钟检查一次
  }

  rotateIfNeeded() {
    const today = new Date().toISOString().split('T')[0]
    if (this.currentDate !== today) {
      this.currentDate = today
      if (this.logStream) this.logStream.end()
      this.logStream = createWriteStream(this.getLogFileName(), { flags: 'a' })
      this.cleanOldLogs()
    }
  }

  cleanOldLogs() {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - this.maxFiles)
    
    try {
      const files = readdirSync(this.logDir)
      files.forEach(file => {
        if (file.startsWith('translate-service-') && file.endsWith('.log')) {
          const dateStr = file.substring(17, 27)
          const fileDate = new Date(dateStr)
          if (fileDate < cutoffDate) {
            unlinkSync(join(this.logDir, file))
          }
        }
      })
    } catch (error) {
      console.error('清理日志失败:', error.message)
    }
  }

  log(level, message) {
    const timestamp = new Date().toISOString()
    const logLine = `${timestamp} [${level.toUpperCase()}] ${message}\n`
    
    if (this.logStream) {
      this.logStream.write(logLine)
    }
    
    // 同时输出到控制台
    console.log(`[${level.toUpperCase()}] ${message}`)
  }

  close() {
    if (this.logStream) {
      this.logStream.end()
    }
  }
}

// ========== 应用配置 ==========
const config = {
  port: process.env.PORT || 3000,
  host: process.env.HOST || '0.0.0.0',
  accessToken: process.env.ACCESS_TOKEN || '',
  nodeEnv: process.env.NODE_ENV || 'production'
}

// ========== 创建应用 ==========
const dailyLogger = new DailyLogger('./logs', 30)

const fastify = Fastify({
  logger: {
    level: 'info',
    targets: [
      {
        // 控制台输出
        target: 'pino-pretty',
        options: {
          colorize: false,
          translateTime: 'yyyy-mm-dd HH:MM:ss Z',
          ignore: 'pid,hostname,reqId,req,res,responseTime'
        }
      },
      {
        // 文件输出
        target: 'pino/file',
        options: {
          destination: './logs/translate-service.log',
          mkdir: true
        }
      }
    ]
  }
})

// ========== 日志处理 ==========
const logHandler = (level, ...args) => {
  const message = args.join(' ')
  
  // 只使用 Fastify 的日志系统，不重复输出
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
    dailyLogger.close()
    process.exit(0)
  })
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))
process.on('exit', () => {
  logger.off(logHandler)
  dailyLogger.close()
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
  return {
    ...getHealthCheck('Google Translate Service'),
    version: '1.0.2',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString(),
    environment: config.nodeEnv
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
    
    const startupInfo = [
      `🚀 Google翻译服务已启动`,
      `📡 服务地址: http://${config.host}:${config.port}`,
      `🏥 健康检查: http://${config.host}:${config.port}/health`,
      `📖 API文档: http://${config.host}:${config.port}/`,
      `🔧 环境: ${config.nodeEnv}`,
      `📊 进程ID: ${process.pid}`
    ]
    
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