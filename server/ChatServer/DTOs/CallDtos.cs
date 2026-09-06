using Chat.Shared.Entities;

namespace ChatServer.DTOs;

/// <summary>來電通知（服務器推送給被叫）。</summary>
public record IncomingCallDto(
    Guid SessionId,
    Guid CallerId,
    string CallerName,
    string? CallerAvatar,
    CallType Type);

/// <summary>通話已接受（雙方開始交換 SDP）。</summary>
public record CallAcceptedDto(
    Guid SessionId,
    Guid CallerId,
    Guid CalleeId,
    CallType Type);

/// <summary>通話結束/拒絕/失敗通知。</summary>
public record CallEndedDto(
    Guid SessionId,
    CallEndReason Reason);

/// <summary>WebRTC SDP 信令轉發。</summary>
public record CallSdpDto(
    Guid SessionId,
    string Sdp);

/// <summary>WebRTC ICE candidate 轉發。</summary>
public record CallIceCandidateDto(
    Guid SessionId,
    string Candidate);
