import * as logger from "firebase-functions/logger";

type LogContext = Record<string, unknown>;

export function createProcessingLogger(baseContext: LogContext) {
  return {
    debug(message: string, context?: LogContext) {
      logger.debug(message, mergeContext(baseContext, context));
    },
    info(message: string, context?: LogContext) {
      logger.info(message, mergeContext(baseContext, context));
    },
    warn(message: string, context?: LogContext) {
      logger.warn(message, mergeContext(baseContext, context));
    },
    error(message: string, error?: unknown, context?: LogContext) {
      logger.error(message, mergeContext(
        baseContext,
        serializeError(error),
        context,
      ));
    },
  };
}

function mergeContext(
  ...contexts: Array<LogContext | undefined>
): LogContext {
  return Object.assign({}, ...contexts.filter(Boolean));
}

export function serializeError(error: unknown): LogContext {
  if (error instanceof Error) {
    const serialized: LogContext = {
      errorName: error.name,
      errorMessage: error.message,
      errorStack: error.stack,
    };

    const errorWithCode = error as Error & { code?: unknown };
    if (typeof errorWithCode.code === "string") {
      serialized.errorCode = errorWithCode.code;
    }

    const errorWithCause = error as Error & { cause?: unknown };
    if (errorWithCause.cause instanceof Error) {
      serialized.errorCause = {
        name: errorWithCause.cause.name,
        message: errorWithCause.cause.message,
      };
    }

    return serialized;
  }

  return { errorMessage: String(error) };
}
