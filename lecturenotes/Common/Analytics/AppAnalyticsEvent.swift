import Foundation

enum AppAnalyticsEvent {
    case onboardingStarted
    case onboardingCompleted(pagesSeenCount: Int)
    case onboardingSkipped(pageIndex: Int)
    case homeOpened(lecturesCount: Int, foldersCount: Int, plan: AppUserPlan?)
    case lectureOpened(context: LectureAnalyticsContext)
    case searchUsed(queryLength: Int, resultsCount: Int, hasFolderFilter: Bool)
    case folderFilterApplied(hasFilter: Bool, filteredCount: Int)
    case recordStarted(limitMinutes: Double, plan: AppUserPlan?)
    case recordPaused(elapsedSeconds: Double)
    case recordResumed(elapsedSeconds: Double)
    case recordFinished(elapsedSeconds: Double, finishReason: String)
    case contentCreateStarted(sourceType: String, entryPoint: String, plan: AppUserPlan?)
    case contentCreateSuccess(context: LectureAnalyticsContext, plan: AppUserPlan?)
    case contentCreateFailed(sourceType: String, entryPoint: String?, plan: AppUserPlan?, reason: String)
    case contentLimitHit(sourceType: String, limitType: String, plan: AppUserPlan?, allowedValue: Double?, actualValue: Double?)
    case processingStarted(context: LectureAnalyticsContext, plan: AppUserPlan?)
    case processingCompleted(context: LectureAnalyticsContext, plan: AppUserPlan?, flashcardsCount: Int, quizCount: Int)
    case processingFailed(context: LectureAnalyticsContext, plan: AppUserPlan?, stage: String, reason: String)
    case processingRetryTapped(context: LectureAnalyticsContext)
    case detailSectionSelected(context: LectureAnalyticsContext, section: String)
    case sectionCopied(context: LectureAnalyticsContext, section: String)
    case audioPlayStarted(context: LectureAnalyticsContext)
    case audioPlayPaused(context: LectureAnalyticsContext, positionSeconds: Double)
    case audioPlayCompleted(context: LectureAnalyticsContext)
    case flashcardsStarted(context: LectureAnalyticsContext, cardsCount: Int)
    case flashcardFlipped(context: LectureAnalyticsContext, cardIndex: Int, isShowingAnswer: Bool)
    case flashcardsCompleted(context: LectureAnalyticsContext, cardsCount: Int)
    case quizStarted(context: LectureAnalyticsContext, questionCount: Int)
    case quizAnswered(context: LectureAnalyticsContext, questionIndex: Int, isCorrect: Bool)
    case quizCompleted(context: LectureAnalyticsContext, correctCount: Int, wrongCount: Int, totalCount: Int)
    case paywallShown(source: String, offeringID: String, currentPlan: AppUserPlan?)
    case purchaseStarted(productID: String, offeringID: String?, planFrom: AppUserPlan)
    case purchaseSuccess(productID: String?, offeringID: String?, planFrom: AppUserPlan, planTo: AppUserPlan)
    case purchaseCancelled(productID: String?, offeringID: String?, planFrom: AppUserPlan)
    case purchaseFailed(productID: String?, offeringID: String?, planFrom: AppUserPlan, error: Error)
    case restorePurchasesStarted(plan: AppUserPlan?)
    case restorePurchasesResult(result: String, restoredPlan: AppUserPlan?)
    case settingsOpened(plan: AppUserPlan?)
    case languageChanged(from: AppLanguage, to: AppLanguage)
    case userIDCopied
    case supportEmailOpened

    var name: String {
        switch self {
        case .onboardingStarted:
            "onboarding_started"
        case .onboardingCompleted:
            "onboarding_completed"
        case .onboardingSkipped:
            "onboarding_skipped"
        case .homeOpened:
            "home_opened"
        case .lectureOpened:
            "lecture_opened"
        case .searchUsed:
            "search_used"
        case .folderFilterApplied:
            "folder_filter_applied"
        case .recordStarted:
            "record_started"
        case .recordPaused:
            "record_paused"
        case .recordResumed:
            "record_resumed"
        case .recordFinished:
            "record_finished"
        case .contentCreateStarted:
            "content_create_started"
        case .contentCreateSuccess:
            "content_create_success"
        case .contentCreateFailed:
            "content_create_failed"
        case .contentLimitHit:
            "content_limit_hit"
        case .processingStarted:
            "processing_started"
        case .processingCompleted:
            "processing_completed"
        case .processingFailed:
            "processing_failed"
        case .processingRetryTapped:
            "processing_retry_tapped"
        case .detailSectionSelected:
            "detail_section_selected"
        case .sectionCopied:
            "section_copied"
        case .audioPlayStarted:
            "audio_play_started"
        case .audioPlayPaused:
            "audio_play_paused"
        case .audioPlayCompleted:
            "audio_play_completed"
        case .flashcardsStarted:
            "flashcards_started"
        case .flashcardFlipped:
            "flashcard_flipped"
        case .flashcardsCompleted:
            "flashcards_completed"
        case .quizStarted:
            "quiz_started"
        case .quizAnswered:
            "quiz_answered"
        case .quizCompleted:
            "quiz_completed"
        case .paywallShown:
            "paywall_shown"
        case .purchaseStarted:
            "purchase_started"
        case .purchaseSuccess:
            "purchase_success"
        case .purchaseCancelled:
            "purchase_cancelled"
        case .purchaseFailed:
            "purchase_failed"
        case .restorePurchasesStarted:
            "restore_purchases_started"
        case .restorePurchasesResult:
            "restore_purchases_result"
        case .settingsOpened:
            "settings_opened"
        case .languageChanged:
            "language_changed"
        case .userIDCopied:
            "user_id_copied"
        case .supportEmailOpened:
            "support_email_opened"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .onboardingStarted:
            return [:]
        case .onboardingCompleted(let pagesSeenCount):
            return [
                "pages_seen_count": pagesSeenCount,
            ]
        case .onboardingSkipped(let pageIndex):
            return [
                "page_index": pageIndex,
            ]
        case .homeOpened(let lecturesCount, let foldersCount, let plan):
            var parameters = planParameters(plan)
            parameters["lectures_count"] = lecturesCount
            parameters["folders_count"] = foldersCount
            return parameters
        case .lectureOpened(let context):
            return lectureParameters(context)
        case .searchUsed(let queryLength, let resultsCount, let hasFolderFilter):
            return [
                "query_length": queryLength,
                "results_count": resultsCount,
                "has_folder_filter": hasFolderFilter,
            ]
        case .folderFilterApplied(let hasFilter, let filteredCount):
            return [
                "has_filter": hasFilter,
                "filtered_count": filteredCount,
            ]
        case .recordStarted(let limitMinutes, let plan):
            var parameters = planParameters(plan)
            parameters["limit_minutes"] = limitMinutes
            return parameters
        case .recordPaused(let elapsedSeconds), .recordResumed(let elapsedSeconds):
            return [
                "elapsed_seconds": elapsedSeconds,
            ]
        case .recordFinished(let elapsedSeconds, let finishReason):
            return [
                "elapsed_seconds": elapsedSeconds,
                "finish_reason": finishReason,
            ]
        case .contentCreateStarted(let sourceType, let entryPoint, let plan):
            var parameters = planParameters(plan)
            parameters["source_type"] = sourceType
            parameters["entry_point"] = entryPoint
            return parameters
        case .contentCreateSuccess(let context, let plan):
            var parameters = lectureParameters(context)
            parameters.merge(planParameters(plan)) { _, newValue in newValue }
            return parameters
        case .contentCreateFailed(let sourceType, let entryPoint, let plan, let reason):
            var parameters = planParameters(plan)
            parameters["source_type"] = sourceType
            parameters["reason"] = Self.sanitized(reason)
            if let entryPoint {
                parameters["entry_point"] = entryPoint
            }
            return parameters
        case .contentLimitHit(let sourceType, let limitType, let plan, let allowedValue, let actualValue):
            var parameters = planParameters(plan)
            parameters["source_type"] = sourceType
            parameters["limit_type"] = limitType
            if let allowedValue {
                parameters["allowed_value"] = allowedValue
            }
            if let actualValue {
                parameters["actual_value"] = actualValue
            }
            return parameters
        case .processingStarted(let context, let plan):
            var parameters = lectureParameters(context)
            parameters.merge(planParameters(plan)) { _, newValue in newValue }
            return parameters
        case .processingCompleted(let context, let plan, let flashcardsCount, let quizCount):
            var parameters = lectureParameters(context)
            parameters.merge(planParameters(plan)) { _, newValue in newValue }
            parameters["flashcards_count"] = flashcardsCount
            parameters["quiz_count"] = quizCount
            return parameters
        case .processingFailed(let context, let plan, let stage, let reason):
            var parameters = lectureParameters(context)
            parameters.merge(planParameters(plan)) { _, newValue in newValue }
            parameters["failure_stage"] = stage
            parameters["reason"] = Self.sanitized(reason)
            return parameters
        case .processingRetryTapped(let context):
            return lectureParameters(context)
        case .detailSectionSelected(let context, let section):
            var parameters = lectureParameters(context)
            parameters["section"] = section
            return parameters
        case .sectionCopied(let context, let section):
            var parameters = lectureParameters(context)
            parameters["section"] = section
            return parameters
        case .audioPlayStarted(let context), .audioPlayCompleted(let context):
            return lectureParameters(context)
        case .audioPlayPaused(let context, let positionSeconds):
            var parameters = lectureParameters(context)
            parameters["position_seconds"] = positionSeconds
            return parameters
        case .flashcardsStarted(let context, let cardsCount), .flashcardsCompleted(let context, let cardsCount):
            var parameters = lectureParameters(context)
            parameters["cards_count"] = cardsCount
            return parameters
        case .flashcardFlipped(let context, let cardIndex, let isShowingAnswer):
            var parameters = lectureParameters(context)
            parameters["card_index"] = cardIndex
            parameters["is_showing_answer"] = isShowingAnswer
            return parameters
        case .quizStarted(let context, let questionCount):
            var parameters = lectureParameters(context)
            parameters["question_count"] = questionCount
            return parameters
        case .quizAnswered(let context, let questionIndex, let isCorrect):
            var parameters = lectureParameters(context)
            parameters["question_index"] = questionIndex
            parameters["is_correct"] = isCorrect
            return parameters
        case .quizCompleted(let context, let correctCount, let wrongCount, let totalCount):
            var parameters = lectureParameters(context)
            parameters["correct_count"] = correctCount
            parameters["wrong_count"] = wrongCount
            parameters["total_count"] = totalCount
            return parameters
        case .paywallShown(let source, let offeringID, let currentPlan):
            var parameters = planParameters(currentPlan)
            parameters["source"] = source
            parameters["offering_id"] = offeringID
            return parameters
        case .purchaseStarted(let productID, let offeringID, let planFrom):
            var parameters: [String: Any] = [
                "plan_from": planFrom.rawValue,
                "product_id": productID,
            ]
            if let offeringID {
                parameters["offering_id"] = offeringID
            }
            return parameters
        case .purchaseSuccess(let productID, let offeringID, let planFrom, let planTo):
            var parameters: [String: Any] = [
                "plan_from": planFrom.rawValue,
                "plan_to": planTo.rawValue,
            ]
            if let productID {
                parameters["product_id"] = productID
            }
            if let offeringID {
                parameters["offering_id"] = offeringID
            }
            return parameters
        case .purchaseCancelled(let productID, let offeringID, let planFrom):
            var parameters: [String: Any] = [
                "plan_from": planFrom.rawValue,
            ]
            if let productID {
                parameters["product_id"] = productID
            }
            if let offeringID {
                parameters["offering_id"] = offeringID
            }
            return parameters
        case .purchaseFailed(let productID, let offeringID, let planFrom, let error):
            let nsError = error as NSError
            var parameters: [String: Any] = [
                "plan_from": planFrom.rawValue,
                "error_code": nsError.code,
                "error_domain": nsError.domain,
            ]
            if let productID {
                parameters["product_id"] = productID
            }
            if let offeringID {
                parameters["offering_id"] = offeringID
            }
            return parameters
        case .restorePurchasesStarted(let plan):
            return planParameters(plan)
        case .restorePurchasesResult(let result, let restoredPlan):
            var parameters: [String: Any] = [
                "result": result,
            ]
            if let restoredPlan {
                parameters["restored_plan"] = restoredPlan.rawValue
            }
            return parameters
        case .settingsOpened(let plan):
            return planParameters(plan)
        case .languageChanged(let from, let to):
            return [
                "from": from.rawValue,
                "to": to.rawValue,
            ]
        case .userIDCopied, .supportEmailOpened:
            return [:]
        }
    }
}

private extension AppAnalyticsEvent {
    static func sanitized(_ value: String) -> String {
        String(value.prefix(96))
    }

    func lectureParameters(_ context: LectureAnalyticsContext) -> [String: Any] {
        [
            "lecture_id": context.lectureID.uuidString,
            "source_type": context.sourceType.rawValue,
            "lecture_status": context.status.rawValue,
            "has_folder": context.hasFolder,
        ]
    }

    func planParameters(_ plan: AppUserPlan?) -> [String: Any] {
        guard let plan else {
            return [:]
        }

        return [
            "plan": plan.rawValue,
        ]
    }
}
