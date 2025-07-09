import { translate } from './translate.js'
import { logger } from './utils.js'

export interface RequestParams {
  text?: string
  source_lang?: string
  target_lang?: string
  token?: string
}

export interface RequestHeaders {
  authorization?: string
  Authorization?: string
}

export interface ParsedTranslateParams {
  text: string
  source_lang: string
  target_lang: string
}

export interface TranslateResponse {
  code: number
  alternatives?: any[]
  data?: string
  source_lang?: string
  target_lang?: string
  id?: number
  method?: string
  message?: string
}

/**
 * 获取 CORS 头配置
 * @returns CORS 头配置对象
 */
export function getCorsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  }
}

/**
 * 解析翻译请求参数并校验 ACCESS_TOKEN
 * @param params 请求参数对象
 * @param headers 请求头对象
 * @param ACCESS_TOKEN 可选的验证令牌
 * @param verbose 是否启用详细日志
 * @returns 解析后的参数对象
 * @throws 参数错误或 token 验证失败时抛出异常
 */
export function parseTranslateParams(
  params: RequestParams,
  headers: RequestHeaders = {},
  ACCESS_TOKEN?: string,
  verbose = false
): ParsedTranslateParams {
  const text = params.text
  const source_lang = params.source_lang || 'auto'
  const target_lang = params.target_lang
  const token = params.token

  // 验证必需参数
  if (!text) {
    if (verbose) {
      logger.error('缺少参数 text')
    }
    throw new Error('缺少参数 text')
  }

  if (!target_lang) {
    if (verbose) {
      logger.error('缺少参数 target_lang')
    }
    throw new Error('缺少参数 target_lang')
  }

  // 验证 ACCESS_TOKEN（如果提供了）
  if (ACCESS_TOKEN) {
    // 从 Authorization 头解析 Bearer token
    const authHeader = headers.Authorization || headers.authorization || ''
    const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null

    // 检查 token 参数或 Authorization 头是否匹配
    if (token !== ACCESS_TOKEN && bearerToken !== ACCESS_TOKEN) {
      if (verbose) {
        logger.error('ACCESS_TOKEN 验证失败')
      }
      throw new Error('ACCESS_TOKEN 验证失败')
    }
  }

  return { text, source_lang, target_lang }
}

/**
 * 获取 API 文档
 * @param description API 描述
 * @param version API 版本
 * @returns API 文档对象
 */
export function getApiDoc(description = 'Google 翻译服务', version = '1.0.0') {
  return {
    name: 'Google 翻译 API',
    version,
    description,
    endpoints: {
      '/translate': {
        methods: ['GET', 'POST'],
        description: '翻译文本',
        parameters: {
          text: '要翻译的文本（必需）',
          source_lang: '源语言代码（可选，默认为 auto）',
          target_lang: '目标语言代码（必需）'
        },
        examples: {
          get: '/translate?text=Hello&source_lang=en&target_lang=zh&token=your_access_token',
          post: {
            url: '/translate',
            body: { text: 'Hello', source_lang: 'en', target_lang: 'zh' },
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer your_access_token'
            }
          }
        }
      },
      '/health': {
        methods: ['GET'],
        description: '健康检查'
      }
    }
  }
}

/**
 * 获取健康检查响应
 * @param serviceName 服务名称
 * @returns 健康检查结果对象
 */
export function getHealthCheck(serviceName = 'Service is running...') {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: serviceName
  }
}

/**
 * 处理翻译请求的通用函数
 * 适用于任何 Web 框架，接受标准化的请求参数和头部
 * @param params 请求参数对象
 * @param headers 请求头对象
 * @param ACCESS_TOKEN 可选的访问令牌
 * @param options 附加选项
 * @returns 标准化的翻译响应
 */
export async function handleTranslateRequest(
  params: RequestParams,
  headers: RequestHeaders = {},
  ACCESS_TOKEN?: string,
  options: { verbose?: boolean } = {}
): Promise<TranslateResponse> {
  try {
    const { verbose = false } = options

    // 解析和验证请求参数
    const { text, source_lang, target_lang } = parseTranslateParams(params, headers, ACCESS_TOKEN, verbose)

    // 调用翻译核心函数
    const googleResult = await translate(text, {
      from: source_lang,
      to: target_lang,
      verbose,
      ...options
    })

    // 返回标准格式的成功响应
    return {
      code: 200,
      alternatives: [],
      data: googleResult.text,
      source_lang: googleResult.sourceLang,
      target_lang: googleResult.targetLang,
      id: Date.now(),
      method: 'Free'
    }
  } catch (error) {
    // 返回标准格式的错误响应
    return {
      code: 500,
      message: error instanceof Error ? error.message : '翻译失败'
    }
  }
}