//
//  ErrorHelpers.swift
//  informed
//
//  User-friendly error messages for various error types
//

import Foundation

/// Provides user-friendly error messages based on error_type from backend
func getUserFriendlyErrorMessage(errorType: String?, fallbackMessage: String) -> String {
    guard let errorType = errorType else {
        return fallbackMessage
    }
    
    switch errorType.lowercased() {
    case "age_restricted":
        return "This video is age-restricted and cannot be fact-checked"
        
    case "unavailable":
        return "Video unavailable or region-locked"
        
    case "invalid_url":
        return "Invalid URL format. Please use Instagram Reel or TikTok video URLs"
        
    case "private_account":
        return "Cannot access videos from private accounts"
        
    case "deleted":
        return "This video has been deleted or removed"
        
    case "network_error":
        return "Network error. Please check your connection and try again"
        
    case "timeout":
        return "Request timed out. Please try again"
        
    case "rate_limited":
        return "Too many requests. Please wait a moment and try again"
        
    case "unsupported_platform":
        return "This platform is not supported. Only Instagram and TikTok videos are supported"
        
    case "video_too_long":
        return "Video is too long. Maximum length is 10 minutes"
        
    case "processing_error":
        return "Error processing video. Please try again"
        
    case "no_speech":
        return "No speech detected in video. Cannot fact-check"
        
    case "copyright":
        return "Video contains copyrighted content and cannot be processed"
        
    default:
        return fallbackMessage
    }
}

/// Provides icon for error type
func getErrorIcon(errorType: String?) -> String {
    guard let errorType = errorType else {
        return "exclamationmark.triangle.fill"
    }
    
    switch errorType.lowercased() {
    case "age_restricted", "private_account":
        return "lock.fill"
        
    case "unavailable", "deleted":
        return "video.slash.fill"
        
    case "invalid_url":
        return "link.badge.xmark"
        
    case "network_error":
        return "wifi.exclamationmark"
        
    case "timeout":
        return "clock.badge.exclamationmark"
        
    case "rate_limited":
        return "hourglass"
        
    case "video_too_long":
        return "timer"
        
    case "no_speech":
        return "waveform.slash"
        
    case "copyright":
        return "c.circle"
        
    default:
        return "exclamationmark.triangle.fill"
    }
}
