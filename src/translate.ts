import { getValue } from './utils.js'
import { logger } from './utils.js'
import { TranslateConfig, TranslateResult, TranslateOptions } from './types.js'

// Google 翻译可用的基础 URL 列表
const GOOGLE_TRANSLATE_BASE_URLS = [
  'translate.googleapis.com',
  'translate.google.com',
  'clients5.google.com',
  'translate.google.so',
  'translate-pa.googleapis.com'
]

// 支持的翻译接口端点
const GOOGLE_TRANSLATE_ENDPOINTS = ['single', 't']
// 支持的客户端类型
const GOOGLE_TRANSLATE_CLIENTS = ['gtx', 'dict-chrome-ex']

// 预生成所有可能的配置并缓存，提高性能
const ALL_CONFIGS_CACHE = (() => {
  const configs: TranslateConfig[] = []

  // 添加 translate-pa.googleapis.com 特殊配置
  configs.push({
    baseUrl: 'translate-pa.googleapis.com',
    isTranslatePa: true
  })

  // 添加其他普通配置的组合
  const otherUrls = GOOGLE_TRANSLATE_BASE_URLS.filter(
    url => url !== 'translate-pa.googleapis.com'
  )

  for (const baseUrl of otherUrls) {
    for (const endpoint of GOOGLE_TRANSLATE_ENDPOINTS) {
      for (const client of GOOGLE_TRANSLATE_CLIENTS) {
        configs.push({
          baseUrl,
          endpoint,
          client,
          isTranslatePa: false
        })
      }
    }
  }

  return configs
})()

/**
 * 验证配置是否有效
 * @param config 待验证的配置
 * @returns 是否有效
 */
function isValidConfig(config: any): config is TranslateConfig {
  if (!config || typeof config !== 'object') {
    return false
  }

  // 检查 baseUrl 是否在有效列表中
  if (!config.baseUrl || !GOOGLE_TRANSLATE_BASE_URLS.includes(config.baseUrl)) {
    return false
  }

  // 如果是 translate-pa.googleapis.com，不需要检查其他字段
  if (config.baseUrl === 'translate-pa.googleapis.com') {
    return true
  }

  // 检查 endpoint 是否在有效列表中
  if (!config.endpoint || !GOOGLE_TRANSLATE_ENDPOINTS.includes(config.endpoint)) {
    return false
  }

  return true
}

/**
 * 生成翻译接口配置数组（优化版）
 * @param preferredConfig 优先使用的配置
 * @param randomizeAll 是否完全随机化所有配置
 * @param verbose 是否启用详细日志
 * @returns 配置数组，按优先级排序
 */
export function generateTranslateConfigs(
  preferredConfig: Partial<TranslateConfig> | null = null, 
  randomizeAll = false, 
  verbose = false
): TranslateConfig[] {
  const configs: TranslateConfig[] = []
  let useRandomOrder = randomizeAll

  // 如果指定了优先配置，先验证
  if (preferredConfig && !randomizeAll) {
    if (!isValidConfig(preferredConfig)) {
      if (verbose) {
        logger.error(`无效的优先配置: ${JSON.stringify(preferredConfig)}`)
        logger.info('将使用随机配置顺序')
      }
      // 验证失败，使用随机顺序
      useRandomOrder = true
    } else {
      // 验证通过，添加优先配置
      if (preferredConfig.baseUrl === 'translate-pa.googleapis.com') {
        configs.push({
          baseUrl: 'translate-pa.googleapis.com',
          isTranslatePa: true
        })
      } else {
        configs.push({
          baseUrl: preferredConfig.baseUrl!,
          endpoint: preferredConfig.endpoint!,
          client: GOOGLE_TRANSLATE_CLIENTS[0],
          isTranslatePa: false
        })
      }

      if (verbose) {
        logger.info(`使用优先配置: ${preferredConfig.baseUrl}${preferredConfig.endpoint ? `/${preferredConfig.endpoint}` : ''}`)
      }
    }
  }

  // 如果没有随机化，且没有有效的优先配置，则使用默认的最高优先级
  if (!useRandomOrder && configs.length === 0) {
    configs.push({
      baseUrl: 'translate-pa.googleapis.com',
      isTranslatePa: true
    })
  }

  // 从缓存中获取其他配置
  const otherConfigs = ALL_CONFIGS_CACHE.filter(config => {
    // 过滤掉已经添加的配置
    return !configs.some(existingConfig =>
      existingConfig.baseUrl === config.baseUrl &&
      existingConfig.endpoint === config.endpoint &&
      existingConfig.client === config.client &&
      existingConfig.isTranslatePa === config.isTranslatePa
    )
  })

  // 如果使用随机顺序，或者需要打乱其他配置
  if (useRandomOrder || otherConfigs.length > 1) {
    for (let i = otherConfigs.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = otherConfigs[i]!;
      otherConfigs[i] = otherConfigs[j]!;
      otherConfigs[j] = temp;
    }
  }

  return [...configs, ...otherConfigs]
}

/**
 * 尝试使用指定配置进行翻译
 * @param config 翻译接口配置
 * @param sourceLang 源语言代码
 * @param targetLang 目标语言代码
 * @param text 待翻译文本
 * @param verbose 是否启用详细日志
 * @returns 翻译结果
 */
async function tryTranslateWithConfig(
  config: TranslateConfig, 
  sourceLang: string, 
  targetLang: string, 
  text: string, 
  verbose: boolean
): Promise<TranslateResult> {
  const headers = new Headers()
  // 设置标准浏览器 User-Agent，避免被识别为机器人
  headers.append(
    'User-Agent',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.104 Safari/537.36'
  )
  headers.append('Accept', '*/*')
  headers.append('Connection', 'keep-alive')
  headers.append('Host', config.baseUrl)

  let response: Response
  let requestUrl: string
  let data: any = null

  if (config.isTranslatePa) {
    // translate-pa.googleapis.com 需要特殊的 API Key 和内容类型
    headers.append('X-Goog-API-Key', 'AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520')
    headers.append('Content-Type', 'application/json+protobuf')

    const requestBody = `[[["${text}"], "${sourceLang}", "${targetLang}"], "wt_lib"]`

    requestUrl = `https://${config.baseUrl}/v1/translateHtml`
    response = await fetch(requestUrl, {
      method: 'POST',
      headers,
      body: requestBody
    })
  } else {
    // 其他接口使用标准的 URL 参数
    const params = new URLSearchParams()
    params.append('client', config.client!)
    params.append('dt', 't')
    params.append('sl', sourceLang)
    params.append('tl', targetLang)
    params.append('q', text)

    headers.append('Content-Type', 'application/json')

    requestUrl = `https://${config.baseUrl}/translate_a/${config.endpoint}`
    const url = `${requestUrl}?${params.toString()}`

    response = await fetch(url, {
      method: 'POST',
      headers,
      redirect: 'follow'
    })
  }

  // 检查响应状态
  if (response.status !== 200) {
    if (verbose) {
      logger.error('请求失败，状态码：', response.status, '域名：', config.baseUrl)
    }

    throw new Error(`请求失败，状态码：${response.status}，域名：${config.baseUrl}`)
  }

  try {
    data = await response.json()

    if (data && Array.isArray(data) && data.length) {
      const firstData = getValue(data, '[0]', '');
      
      if (config.isTranslatePa) {
        // translate-pa.googleapis.com 的响应格式
        return {
          text: getValue(firstData, '[0]', ''),
          sourceLang: getValue(data, '[1][0]', '') || sourceLang,
          targetLang
        }
      }

      if (config.endpoint === 'single') {
        // single 端点的响应格式
        return {
          text: (firstData || []).map((item: any) => getValue(item, '[0]', '') || '').join(''),
          sourceLang: getValue(data, '[2]', null) || sourceLang,
          targetLang
        }
      }

      if (config.endpoint === 't') {
        // t 端点的响应格式
        const isArr = firstData && Array.isArray(firstData) && firstData.length;
        
        return {
          text: (isArr ? getValue(firstData, '[0]', '') : firstData) || '',
          sourceLang: (isArr ? getValue(firstData, '[1]', '') : '') || sourceLang,
          targetLang
        }
      }
    }

    if (verbose) {
      logger.error('无返回数据')
    }

    throw new Error('无返回数据')
  } catch (error) {
    if (verbose) {
      logger.error('处理响应数据时出错:', error)
      logger.error('响应数据:', JSON.stringify(data))
    }

    throw error
  }
}

/**
 * 调用 Google 翻译接口进行翻译（支持智能重试）
 * @param text 待翻译文本
 * @param options 翻译选项
 * @returns 翻译结果
 * @throws 当所有接口都失败时抛出错误
 */
export async function translate(text: string, options: TranslateOptions): Promise<TranslateResult> {
  const {
    from = 'auto',
    to,
    verbose = false,
    preferredConfig = null,
    randomizeAll = false
  } = options

  // 验证必需参数
  if (!text) {
    if (verbose) {
      logger.error('缺少必需参数: text')
    }
    throw new Error('缺少必需参数: text')
  }

  if (!to) {
    if (verbose) {
      logger.error('缺少必需参数: to')
    }
    throw new Error('缺少必需参数: to')
  }

  // 生成配置列表
  const configs = generateTranslateConfigs(preferredConfig, randomizeAll, verbose)
  const errors: string[] = []

  if (verbose) {
    logger.info(`开始翻译: ${from} -> ${to}, 文本长度: ${text.length}`)
    logger.info(`生成了 ${configs.length} 个配置`)
    if (randomizeAll) {
      logger.info('使用完全随机化配置顺序')
    }
  }

  // 遍历所有配置，直到成功或全部失败
  for (let i = 0; i < configs.length; i++) {
    const config = configs[i];
    if (!config) continue;

    try {
      if (verbose) {
        logger.info(
          `尝试配置 ${i + 1}/${configs.length}: ${config.baseUrl}${
            config.endpoint ? `/${config.endpoint}` : ''
          }`
        )
      }

      const result = await tryTranslateWithConfig(config, from, to, text, verbose)

      if (verbose) {
        logger.info(
          `翻译成功! 使用配置: ${config.baseUrl}${
            config.endpoint ? `/${config.endpoint}` : ''
          }`
        )
      }

      return result
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error)
      errors.push(`配置${i + 1}(${config.baseUrl}): ${errorMsg}`)

      if (verbose) {
        logger.info(`配置 ${i + 1} 失败: ${errorMsg}`)
      }

      // 继续尝试下一个配置
      if (i < configs.length - 1) {
        continue
      }
    }
  }

  // 所有配置都失败了
  const finalError = `所有翻译接口都失败了。尝试了 ${configs.length} 个配置:\n${errors.join('\n')}`

  if (verbose) {
    logger.error(finalError)
  }

  throw new Error(finalError)
}