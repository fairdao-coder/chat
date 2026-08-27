using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using MauiChat.Config;
using MauiChat.Models;
using Microsoft.Maui.Storage;

namespace MauiChat.Services;

/// <summary>
/// Thin REST client for every HTTP endpoint in ARCHITECTURE.md.
/// Adds the JWT <c>Authorization: Bearer</c> header automatically from
/// SecureStorage on each call. File upload uses multipart/form-data.
/// </summary>
public class ApiClient
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly HttpClient _http;

    public ApiClient(HttpClient http)
    {
        _http = http;
        _http.BaseAddress = new Uri(AppConfig.ApiBase);
        _http.Timeout = TimeSpan.FromSeconds(30);
    }

    // ---------- Auth ----------

    public Task<AuthResult> LoginAsync(string userName, string password)
        => PostJsonAsync<AuthResult>("/api/auth/login",
            new { userName, password });

    public Task<AuthResult> RegisterAsync(string userName, string password, string nickName)
        => PostJsonAsync<AuthResult>("/api/auth/register",
            new { userName, password, nickName });

    // ---------- Conversations / Contacts ----------

    public Task<List<ContactDto>> GetConversationsAsync()
        => GetAsync<List<ContactDto>>("/api/conversations");

    // ---------- Users ----------

    public Task<List<UserDto>> SearchUsersAsync(string q)
        => GetAsync<List<UserDto>>("/api/users/search?q=" + Uri.EscapeDataString(q));

    // ---------- Friends ----------

    /// <summary>POST /api/friends/request  body = "&lt;friendId&gt;" (Guid as raw JSON string).</summary>
    public Task SendFriendRequestAsync(Guid friendId)
        => PostRawAsync("/api/friends/request", Quote(friendId.ToString()));

    /// <summary>GET /api/friends/requests  (incoming pending requests).</summary>
    public Task<List<FriendRequestDto>> GetFriendRequestsAsync()
        => GetAsync<List<FriendRequestDto>>("/api/friends/requests");

    /// <summary>POST /api/friends/accept  body = "&lt;requesterId&gt;" (Guid as raw JSON string).</summary>
    public Task AcceptFriendRequestAsync(Guid requesterId)
        => PostRawAsync("/api/friends/accept", Quote(requesterId.ToString()));

    /// <summary>GET /api/friends  (my friend list).</summary>
    public Task<List<UserDto>> GetFriendsAsync()
        => GetAsync<List<UserDto>>("/api/friends");

    // ---------- Groups ----------

    public Task CreateGroupAsync(string name, List<Guid> memberIds)
        => PostJsonAsync<object>("/api/groups", new { name, memberIds });

    public Task<List<GroupDto>> GetGroupsAsync()
        => GetAsync<List<GroupDto>>("/api/groups");

    // ---------- Messages ----------

    public Task<List<MessageDto>> GetPrivateHistoryAsync(Guid friendId, DateTime? before = null, int count = 30)
        => GetAsync<List<MessageDto>>(HistoryQuery($"/api/messages/private/{friendId}", before, count));

    public Task<List<MessageDto>> GetGroupHistoryAsync(Guid groupId, DateTime? before = null, int count = 30)
        => GetAsync<List<MessageDto>>(HistoryQuery($"/api/messages/group/{groupId}", before, count));

    // ---------- Files ----------

    /// <summary>POST /api/files/upload  multipart/form-data, field name "file".</summary>
    public async Task<FileUploadResult> UploadFileAsync(Stream content, string fileName, string contentType)
    {
        await EnsureAuthHeader();

        using var form = new MultipartFormDataContent();
        var fileContent = new StreamContent(content);
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
        form.Add(fileContent, "file", fileName);

        using var resp = await _http.PostAsync("/api/files/upload", form);
        return await ReadOrThrow<FileUploadResult>(resp);
    }

    // ---------- Internals ----------

    private static string HistoryQuery(string path, DateTime? before, int count)
    {
        var q = $"{path}?count={count}";
        if (before.HasValue)
            q += "&before=" + Uri.EscapeDataString(before.Value.ToString("o"));
        return q;
    }

    private static string Quote(string s) => "\"" + s.Replace("\"", "\\\"") + "\"";

    private async Task EnsureAuthHeader()
    {
        var token = await SecureStorage.Default.GetAsync(AuthKeys.TokenKey);
        _http.DefaultRequestHeaders.Authorization =
            string.IsNullOrEmpty(token) ? null : new AuthenticationHeaderValue("Bearer", token);
    }

    private async Task<T> GetAsync<T>(string path)
    {
        await EnsureAuthHeader();
        using var resp = await _http.GetAsync(path);
        return await ReadOrThrow<T>(resp);
    }

    private async Task<T> PostJsonAsync<T>(string path, object body)
    {
        await EnsureAuthHeader();
        using var content = JsonContent.Create(body, options: JsonOptions);
        using var resp = await _http.PostAsync(path, content);
        return await ReadOrThrow<T>(resp);
    }

    private async Task PostRawAsync(string path, string rawJson)
    {
        await EnsureAuthHeader();
        using var content = new StringContent(rawJson, Encoding.UTF8, "application/json");
        using var resp = await _http.PostAsync(path, content);
        await EnsureSuccess(resp);
    }

    private static async Task EnsureSuccess(HttpResponseMessage resp)
    {
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException($"{(int)resp.StatusCode} {resp.ReasonPhrase}: {await resp.Content.ReadAsStringAsync()}");
    }

    private static async Task<T> ReadOrThrow<T>(HttpResponseMessage resp)
    {
        await EnsureSuccess(resp);
        var json = await resp.Content.ReadAsStringAsync();
        if (string.IsNullOrWhiteSpace(json))
            return default!;
        return JsonSerializer.Deserialize<T>(json, JsonOptions)
               ?? throw new JsonException($"Failed to deserialize response from {resp.RequestMessage?.RequestUri}");
    }
}
