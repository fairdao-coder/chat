import 'package:flutter/material.dart';

/// 後臺管理界面支持的顯示語言。
///
/// 僅影響本機界面文案，寫入 SharedPreferences，不下發到後端。
enum AppLocale {
  zhHant('zh', 'TW', '繁體中文'),
  zhHans('zh', 'CN', '简体中文'),
  en('en', 'US', 'English'),
  es('es', 'ES', 'Español');

  const AppLocale(this.languageCode, this.countryCode, this.nativeName);

  final String languageCode;
  final String countryCode;

  /// 語言自身的名稱：切換器裏始終以該語言的本名顯示，便於辨認。
  final String nativeName;

  Locale toLocale() => Locale(languageCode, countryCode);

  static List<Locale> get supported =>
      values.map((e) => e.toLocale()).toList(growable: false);
}

/// 文案 key 常量。
///
/// 新增界面文案時：在此加 key，再到 [_zhHant] / [_zhHans] / [_en] / [_es]
/// 四張表補齊；缺失的 key 會自動回落到繁體中文（見 [Strings]）。
class K {
  // —— 通用 ——
  static const save = 'common.save';
  static const saved = 'common.saved';
  static const retry = 'common.retry';
  static const cancel = 'common.cancel';
  static const confirm = 'common.confirm';
  static const readOnly = 'common.readOnly';
  static const saveFailed = 'common.saveFailed';
  static const language = 'common.language';
  static const languageDesc = 'common.languageDesc';

  // —— 登錄頁 ——
  static const appTitle = 'app.title';
  static const appSubtitle = 'app.subtitle';
  static const loginAccount = 'login.account';
  static const loginPassword = 'login.password';
  static const loginSubmit = 'login.submit';
  static const loginHint = 'login.hint';
  static const loginWelcome = 'login.welcome';
  static const loginSlogan = 'login.slogan';
  static const featUsers = 'login.featUsers';
  static const featRoles = 'login.featRoles';
  static const featDiscover = 'login.featDiscover';
  static const featSettings = 'login.featSettings';
  static const errorNetwork = 'error.network';
  static const errorNetworkRetry = 'error.networkRetry';

  // —— 側欄導航 ——
  static const navDashboard = 'nav.dashboard';
  static const navUsers = 'nav.users';
  static const navService = 'nav.service';
  static const navRoles = 'nav.roles';
  static const navAudit = 'nav.audit';
  static const navAdmins = 'nav.admins';
  static const navDiscover = 'nav.discover';
  static const navSettings = 'nav.settings';
  static const adminConsole = 'nav.console';
  static const noModule = 'nav.noModule';
  static const logout = 'bar.logout';

  // —— 修改密碼 ——
  static const changePwd = 'pwd.title';
  static const pwdOld = 'pwd.old';
  static const pwdNew = 'pwd.new';
  static const pwdConfirm = 'pwd.confirm';
  static const pwdNewHint = 'pwd.newHint';
  static const pwdRequired = 'pwd.required';
  static const pwdTooShort = 'pwd.tooShort';
  static const pwdMismatch = 'pwd.mismatch';
  static const pwdSuccess = 'pwd.success';

  // —— 系統配置頁 ——
  static const saving = 'cfg.saving';
  static const saveConfig = 'cfg.saveConfig';
  static const reset = 'cfg.reset';
  static const lastUpdated = 'cfg.lastUpdated';

  // —— 通用補充 ——
  static const loadFailed = 'error.loadFailed';
  static const search = 'common.search';

  // —— 儀表盤 ——
  static const dashTitle = 'dash.title';
  static const dashUsers = 'dash.users';
  static const dashNewToday = 'dash.newToday';
  static const dashOnline = 'dash.online';
  static const dashBanned = 'dash.banned';
  static const dashTotalMsg = 'dash.totalMsg';
  static const dashTodayMsg = 'dash.todayMsg';
  static const dashGroups = 'dash.groups';
  static const dashFriendships = 'dash.friendships';
  static const dashSignupTrend = 'dash.signupTrend';
  static const dashMsgTrend = 'dash.msgTrend';

  // —— 審計日誌 ——
  static const auditSearchHint = 'audit.searchHint';
  static const auditTotal = 'audit.total';
  static const auditPage = 'audit.page';
  static const colTime = 'col.time';
  static const colOperator = 'col.operator';
  static const colAction = 'col.action';
  static const colTarget = 'col.target';
  static const colDetail = 'col.detail';

  // —— 用戶管理 ——
  static const edit = 'common.edit';
  static const actions = 'common.actions';
  static const pagerPage = 'pager.page';
  static const userEditTitle = 'user.editTitle';
  static const userNickname = 'user.nickname';
  static const userBanTitle = 'user.banTitle';
  static const userUnbanTitle = 'user.unbanTitle';
  static const userConfirmBan = 'user.confirmBan';
  static const userConfirmUnban = 'user.confirmUnban';
  static const userReason = 'user.reason';
  static const userBan = 'user.ban';
  static const userUnban = 'user.unban';
  static const userSearchHint = 'user.searchHint';
  static const userTotal = 'user.total';
  static const userUsername = 'user.username';
  static const userStatus = 'user.status';
  static const userCreatedAt = 'user.createdAt';
  static const userOnline = 'user.online';
  static const userBanned = 'user.banned';
  static const userOffline = 'user.offline';

  // —— 角色 / 管理員 ——
  static const delete = 'common.delete';
  static const create = 'common.create';
  static const enabled = 'common.enabled';
  static const disabled = 'common.disabled';
  static const permViewDashboard = 'perm.viewDashboard';
  static const permViewUsers = 'perm.viewUsers';
  static const permManageUsers = 'perm.manageUsers';
  static const permViewRoles = 'perm.viewRoles';
  static const permManageRoles = 'perm.manageRoles';
  static const permViewAudit = 'perm.viewAudit';
  static const permViewAdmins = 'perm.viewAdmins';
  static const permManageAdmins = 'perm.manageAdmins';
  static const roleName = 'role.name';
  static const roleNewTitle = 'role.newTitle';
  static const roleEditTitle = 'role.editTitle';
  static const roleDesc = 'role.desc';
  static const rolePerms = 'role.perms';
  static const roleDeleteTitle = 'role.deleteTitle';
  static const roleConfirmDelete = 'role.confirmDelete';
  static const roleNoPerm = 'role.noPerm';
  static const adminTitle = 'admin.title';
  static const adminNewTitle = 'admin.newTitle';
  static const adminUsername = 'admin.username';
  static const adminDisplayName = 'admin.displayName';
  static const adminSubtitle = 'admin.subtitle';

  // —— 客服帳號 ——
  static const svcTitle = 'svc.title';
  static const svcDesc = 'svc.desc';
  static const svcAdd = 'svc.add';
  static const svcNewTitle = 'svc.newTitle';
  static const svcMinChars3 = 'svc.minChars3';
  static const svcNameRequired = 'svc.nameRequired';
  static const svcLoginPwd = 'svc.loginPwd';
  static const svcCreated = 'svc.created';
  static const svcRemoveTitle = 'svc.removeTitle';
  static const svcRemoveConfirm = 'svc.removeConfirm';
  static const svcRemove = 'svc.remove';
  static const svcRemoved = 'svc.removed';
  static const svcRemoveFailed = 'svc.removeFailed';
  static const svcEmpty = 'svc.empty';
  static const svcRemoveAgent = 'svc.removeAgent';

  // —— 發現頁欄目 ——
  static const discPinLimit = 'disc.pinLimit';
  static const discCreated = 'disc.created';
  static const discOpFailed = 'disc.opFailed';
  static const discConfirmDeleteTitle = 'disc.confirmDeleteTitle';
  static const discConfirmDelete = 'disc.confirmDelete';
  static const discDeleted = 'disc.deleted';
  static const discDeleteFailed = 'disc.deleteFailed';
  static const discAdd = 'disc.add';
  static const discRefresh = 'disc.refresh';
  static const discEmpty = 'disc.empty';
  static const discPinned = 'disc.pinned';
  static const discHidden = 'disc.hidden';
  static const discUnpin = 'disc.unpin';
  static const discPin = 'disc.pin';

  // —— 功能開關項 ——
  static const featOnline = 'feat.online';
  static const featOnlineDesc = 'feat.onlineDesc';
  static const featVoiceCall = 'feat.voiceCall';
  static const featVoiceCallDesc = 'feat.voiceCallDesc';
  static const featVideoCall = 'feat.videoCall';
  static const featVideoCallDesc = 'feat.videoCallDesc';
  static const featFile = 'feat.file';
  static const featFileDesc = 'feat.fileDesc';
  static const featVoice = 'feat.voice';
  static const featVoiceDesc = 'feat.voiceDesc';
  static const featRegister = 'feat.register';
  static const featRegisterDesc = 'feat.registerDesc';

  // —— ICE 服務器卡片 ——
  static const iceTitle = 'ice.title';
  static const iceDesc = 'ice.desc';
  static const iceAdd = 'ice.add';
  static const iceServer = 'ice.server';
  static const iceUrls = 'ice.urls';
  static const iceUsername = 'ice.username';
  static const iceCredential = 'ice.credential';
  static const iceCredType = 'ice.credType';
  static const iceCredPassword = 'ice.credPassword';
}

// ——————————————————————————— 各語言文案表 ———————————————————————————

const _zhHant = <String, String>{
  K.save: '保存',
  K.saved: '已保存',
  K.retry: '重試',
  K.cancel: '取消',
  K.confirm: '確認修改',
  K.readOnly: '當前角色僅有只讀權限，無法修改配置。',
  K.saveFailed: '保存失敗：',
  K.language: '界面語言',
  K.languageDesc: '切換後臺管理界面的顯示語言（僅影響本機，不下發到客戶端）。',
  K.appTitle: '聊天後臺管理系統',
  K.appSubtitle: 'Chat Admin Console',
  K.loginAccount: '管理員賬號',
  K.loginPassword: '密碼',
  K.loginSubmit: '登 錄',
  K.loginHint: '默認賬號 admin / admin123',
  K.loginWelcome: '歡迎回來',
  K.loginSlogan: '統一管理用戶、角色、發現頁與系統功能配置。',
  K.featUsers: '用戶管理',
  K.featRoles: '角色權限',
  K.featDiscover: '發現頁',
  K.featSettings: '系統配置',
  K.errorNetwork: '網絡錯誤',
  K.errorNetworkRetry: '網絡錯誤，請重試',
  K.navDashboard: '儀表盤',
  K.navUsers: '用戶管理',
  K.navService: '客服管理',
  K.navRoles: '角色管理',
  K.navAudit: '審計日誌',
  K.navAdmins: '管理員',
  K.navDiscover: '發現頁欄目',
  K.navSettings: '系統配置',
  K.adminConsole: '後臺管理',
  K.noModule: '無可用模塊',
  K.logout: '退出登錄',
  K.changePwd: '修改密碼',
  K.pwdOld: '舊密碼',
  K.pwdNew: '新密碼',
  K.pwdConfirm: '確認新密碼',
  K.pwdNewHint: '至少6位',
  K.pwdRequired: '請輸入舊密碼',
  K.pwdTooShort: '密碼長度至少6位',
  K.pwdMismatch: '兩次輸入的新密碼不一致',
  K.pwdSuccess: '密碼修改成功',
  K.saving: '保存中...',
  K.saveConfig: '保存配置',
  K.reset: '重置',
  K.lastUpdated: '最後更新：',
  K.loadFailed: '加載失敗：',
  K.search: '搜索',
  K.dashTitle: '數據概覽',
  K.dashUsers: '註冊用戶',
  K.dashNewToday: '今日新增',
  K.dashOnline: '在線用戶',
  K.dashBanned: '封禁用戶',
  K.dashTotalMsg: '總消息',
  K.dashTodayMsg: '今日消息',
  K.dashGroups: '群組數',
  K.dashFriendships: '好友關係',
  K.dashSignupTrend: '近 {d} 天註冊趨勢',
  K.dashMsgTrend: '近 {d} 天消息量',
  K.auditSearchHint: '搜索動作 / 操作人',
  K.auditTotal: '共 {n} 條',
  K.auditPage: '第 {a} / {b} 頁',
  K.colTime: '時間',
  K.colOperator: '操作人',
  K.colAction: '動作',
  K.colTarget: '目標',
  K.colDetail: '詳情',
  K.edit: '編輯',
  K.actions: '操作',
  K.pagerPage: '第 {a} / {b} 頁',
  K.userEditTitle: '編輯用戶資料',
  K.userNickname: '暱稱',
  K.userBanTitle: '封禁用戶',
  K.userUnbanTitle: '解封用戶',
  K.userConfirmBan: '確認封禁 @{u}？',
  K.userConfirmUnban: '確認解封 @{u}？',
  K.userReason: '原因（可選）',
  K.userBan: '封禁',
  K.userUnban: '解封',
  K.userSearchHint: '搜索用戶名 / 暱稱',
  K.userTotal: '共 {n} 個用戶',
  K.userUsername: '用戶名',
  K.userStatus: '狀態',
  K.userCreatedAt: '註冊時間',
  K.userOnline: '在線',
  K.userBanned: '已封禁',
  K.userOffline: '離線',
  K.delete: '刪除',
  K.create: '創建',
  K.enabled: '啟用',
  K.disabled: '停用',
  K.permViewDashboard: '查看儀表盤',
  K.permViewUsers: '查看用戶',
  K.permManageUsers: '管理用戶（編輯/封禁）',
  K.permViewRoles: '查看角色',
  K.permManageRoles: '管理角色',
  K.permViewAudit: '查看審計日誌',
  K.permViewAdmins: '查看管理員',
  K.permManageAdmins: '管理管理員',
  K.roleName: '角色名',
  K.roleNewTitle: '新建角色',
  K.roleEditTitle: '編輯角色',
  K.roleDesc: '描述',
  K.rolePerms: '權限',
  K.roleDeleteTitle: '刪除角色',
  K.roleConfirmDelete: '確認刪除角色「{n}」？',
  K.roleNoPerm: '（無權限）',
  K.adminTitle: '管理員賬號',
  K.adminNewTitle: '新建管理員',
  K.adminUsername: '登錄賬號',
  K.adminDisplayName: '顯示名稱',
  K.adminSubtitle: '角色：{r}  ·  創建於 {d}',
  K.svcTitle: '客服帳號',
  K.svcDesc: '創建多個客服帳號，用戶「聯繫客服」時可選擇在線客服直接對話（免好友關係）。',
  K.svcAdd: '新增客服',
  K.svcNewTitle: '新增客服帳號',
  K.svcMinChars3: '至少3個字元',
  K.svcNameRequired: '請填寫顯示名稱',
  K.svcLoginPwd: '登錄密碼',
  K.svcCreated: '客服帳號已創建',
  K.svcRemoveTitle: '移除客服帳號',
  K.svcRemoveConfirm: '確定將「{n}」移出客服？該帳號將保留為普通用戶，歷史會話不會丟失。',
  K.svcRemove: '移除',
  K.svcRemoved: '已移出客服',
  K.svcRemoveFailed: '移除失敗: ',
  K.svcEmpty: '暫無客服帳號，點擊右上角新增',
  K.svcRemoveAgent: '移除客服',
  K.discPinLimit: '固定欄目最多 {n} 個，請先取消其它欄目的固定',
  K.discCreated: '已新增',
  K.discOpFailed: '操作失敗：',
  K.discConfirmDeleteTitle: '確認刪除',
  K.discConfirmDelete: '確定刪除欄目「{n}」？',
  K.discDeleted: '已刪除',
  K.discDeleteFailed: '刪除失敗：',
  K.discAdd: '新增欄目',
  K.discRefresh: '刷新',
  K.discEmpty: '暫無欄目',
  K.discPinned: '固定',
  K.discHidden: '已隱藏',
  K.discUnpin: '取消固定',
  K.discPin: '固定到底部導航',
  K.featOnline: '顯示在線狀態',
  K.featOnlineDesc: '在用戶頭像與聊天列表展示在線/離線標識',
  K.featVoiceCall: '啟用語音通話',
  K.featVoiceCallDesc: '允許用戶發起一對一語音通話',
  K.featVideoCall: '啟用視頻通話',
  K.featVideoCallDesc: '允許用戶發起一對一視頻通話',
  K.featFile: '允許發送文件',
  K.featFileDesc: '在聊天輸入框顯示文件發送入口',
  K.featVoice: '允許發送語音',
  K.featVoiceDesc: '在聊天輸入框顯示語音錄制入口',
  K.featRegister: '允許用戶註冊',
  K.featRegisterDesc: '關閉後，普通用戶將無法在登錄頁自助註冊新帳號（僅後台可建立）',
  K.iceTitle: 'WebRTC 實時通信（STUN/TURN）',
  K.iceDesc: '配置語音/視頻通話使用的 ICE 服務器。僅填 STUN 即可在同網絡通話；'
      '跨網絡（如手機流量與 WiFi）建議配置 TURN 中繼。留空則客戶端回落默認 STUN。',
  K.iceAdd: '添加服務器',
  K.iceServer: '服務器 {n}',
  K.iceUrls: '地址（多個以逗號分隔）',
  K.iceUsername: '用戶名（TURN 選填）',
  K.iceCredential: '憑證（TURN 選填）',
  K.iceCredType: '憑證類型',
  K.iceCredPassword: '密碼（默認）',
};

const _zhHans = <String, String>{
  K.save: '保存',
  K.saved: '已保存',
  K.retry: '重试',
  K.cancel: '取消',
  K.confirm: '确认修改',
  K.readOnly: '当前角色仅有只读权限，无法修改配置。',
  K.saveFailed: '保存失败：',
  K.language: '界面语言',
  K.languageDesc: '切换后台管理界面的显示语言（仅影响本机，不下发到客户端）。',
  K.appTitle: '聊天后台管理系统',
  K.appSubtitle: 'Chat Admin Console',
  K.loginAccount: '管理员账号',
  K.loginPassword: '密码',
  K.loginSubmit: '登 录',
  K.loginHint: '默认账号 admin / admin123',
  K.loginWelcome: '欢迎回来',
  K.loginSlogan: '统一管理用户、角色、发现页与系统功能配置。',
  K.featUsers: '用户管理',
  K.featRoles: '角色权限',
  K.featDiscover: '发现页',
  K.featSettings: '系统配置',
  K.errorNetwork: '网络错误',
  K.errorNetworkRetry: '网络错误，请重试',
  K.navDashboard: '仪表盘',
  K.navUsers: '用户管理',
  K.navService: '客服管理',
  K.navRoles: '角色管理',
  K.navAudit: '审计日志',
  K.navAdmins: '管理员',
  K.navDiscover: '发现页栏目',
  K.navSettings: '系统配置',
  K.adminConsole: '后台管理',
  K.noModule: '无可用模块',
  K.logout: '退出登录',
  K.changePwd: '修改密码',
  K.pwdOld: '旧密码',
  K.pwdNew: '新密码',
  K.pwdConfirm: '确认新密码',
  K.pwdNewHint: '至少6位',
  K.pwdRequired: '请输入旧密码',
  K.pwdTooShort: '密码长度至少6位',
  K.pwdMismatch: '两次输入的新密码不一致',
  K.pwdSuccess: '密码修改成功',
  K.saving: '保存中...',
  K.saveConfig: '保存配置',
  K.reset: '重置',
  K.lastUpdated: '最后更新：',
  K.loadFailed: '加载失败：',
  K.search: '搜索',
  K.dashTitle: '数据概览',
  K.dashUsers: '注册用户',
  K.dashNewToday: '今日新增',
  K.dashOnline: '在线用户',
  K.dashBanned: '封禁用户',
  K.dashTotalMsg: '总消息',
  K.dashTodayMsg: '今日消息',
  K.dashGroups: '群组数',
  K.dashFriendships: '好友关系',
  K.dashSignupTrend: '近 {d} 天注册趋势',
  K.dashMsgTrend: '近 {d} 天消息量',
  K.auditSearchHint: '搜索动作 / 操作人',
  K.auditTotal: '共 {n} 条',
  K.auditPage: '第 {a} / {b} 页',
  K.colTime: '时间',
  K.colOperator: '操作人',
  K.colAction: '动作',
  K.colTarget: '目标',
  K.colDetail: '详情',
  K.edit: '编辑',
  K.actions: '操作',
  K.pagerPage: '第 {a} / {b} 页',
  K.userEditTitle: '编辑用户资料',
  K.userNickname: '昵称',
  K.userBanTitle: '封禁用户',
  K.userUnbanTitle: '解封用户',
  K.userConfirmBan: '确认封禁 @{u}？',
  K.userConfirmUnban: '确认解封 @{u}？',
  K.userReason: '原因（可选）',
  K.userBan: '封禁',
  K.userUnban: '解封',
  K.userSearchHint: '搜索用户名 / 昵称',
  K.userTotal: '共 {n} 个用户',
  K.userUsername: '用户名',
  K.userStatus: '状态',
  K.userCreatedAt: '注册时间',
  K.userOnline: '在线',
  K.userBanned: '已封禁',
  K.userOffline: '离线',
  K.delete: '删除',
  K.create: '创建',
  K.enabled: '启用',
  K.disabled: '停用',
  K.permViewDashboard: '查看仪表盘',
  K.permViewUsers: '查看用户',
  K.permManageUsers: '管理用户（编辑/封禁）',
  K.permViewRoles: '查看角色',
  K.permManageRoles: '管理角色',
  K.permViewAudit: '查看审计日志',
  K.permViewAdmins: '查看管理员',
  K.permManageAdmins: '管理管理员',
  K.roleName: '角色名',
  K.roleNewTitle: '新建角色',
  K.roleEditTitle: '编辑角色',
  K.roleDesc: '描述',
  K.rolePerms: '权限',
  K.roleDeleteTitle: '删除角色',
  K.roleConfirmDelete: '确认删除角色「{n}」？',
  K.roleNoPerm: '（无权限）',
  K.adminTitle: '管理员账号',
  K.adminNewTitle: '新建管理员',
  K.adminUsername: '登录账号',
  K.adminDisplayName: '显示名称',
  K.adminSubtitle: '角色：{r}  ·  创建于 {d}',
  K.svcTitle: '客服账号',
  K.svcDesc: '创建多个客服账号，用户「联系客服」时可选择在线客服直接对话（免好友关系）。',
  K.svcAdd: '新增客服',
  K.svcNewTitle: '新增客服账号',
  K.svcMinChars3: '至少3个字符',
  K.svcNameRequired: '请填写显示名称',
  K.svcLoginPwd: '登录密码',
  K.svcCreated: '客服账号已创建',
  K.svcRemoveTitle: '移除客服账号',
  K.svcRemoveConfirm: '确定将「{n}」移出客服？该账号将保留为普通用户，历史会话不会丢失。',
  K.svcRemove: '移除',
  K.svcRemoved: '已移出客服',
  K.svcRemoveFailed: '移除失败: ',
  K.svcEmpty: '暂无客服账号，点击右上角新增',
  K.svcRemoveAgent: '移除客服',
  K.discPinLimit: '固定栏目最多 {n} 个，请先取消其它栏目的固定',
  K.discCreated: '已新增',
  K.discOpFailed: '操作失败：',
  K.discConfirmDeleteTitle: '确认删除',
  K.discConfirmDelete: '确定删除栏目「{n}」？',
  K.discDeleted: '已删除',
  K.discDeleteFailed: '删除失败：',
  K.discAdd: '新增栏目',
  K.discRefresh: '刷新',
  K.discEmpty: '暂无栏目',
  K.discPinned: '固定',
  K.discHidden: '已隐藏',
  K.discUnpin: '取消固定',
  K.discPin: '固定到底部导航',
  K.featOnline: '显示在线状态',
  K.featOnlineDesc: '在用户头像与聊天列表展示在线/离线标识',
  K.featVoiceCall: '启用语音通话',
  K.featVoiceCallDesc: '允许用户发起一对一语音通话',
  K.featVideoCall: '启用视频通话',
  K.featVideoCallDesc: '允许用户发起一对一视频通话',
  K.featFile: '允许发送文件',
  K.featFileDesc: '在聊天输入框显示文件发送入口',
  K.featVoice: '允许发送语音',
  K.featVoiceDesc: '在聊天输入框显示语音录制入口',
  K.featRegister: '允许用户注册',
  K.featRegisterDesc: '关闭后，普通用户将无法在登录页自助注册新账号（仅后台可建立）',
  K.iceTitle: 'WebRTC 实时通信（STUN/TURN）',
  K.iceDesc: '配置语音/视频通话使用的 ICE 服务器。仅填 STUN 即可在同网络通话；'
      '跨网络（如手机流量与 WiFi）建议配置 TURN 中继。留空则客户端回落默认 STUN。',
  K.iceAdd: '添加服务器',
  K.iceServer: '服务器 {n}',
  K.iceUrls: '地址（多个以逗号分隔）',
  K.iceUsername: '用户名（TURN 选填）',
  K.iceCredential: '凭证（TURN 选填）',
  K.iceCredType: '凭证类型',
  K.iceCredPassword: '密码（默认）',
};

const _en = <String, String>{
  K.save: 'Save',
  K.saved: 'Saved',
  K.retry: 'Retry',
  K.cancel: 'Cancel',
  K.confirm: 'Save changes',
  K.readOnly: 'Your role has read-only access; configuration cannot be modified.',
  K.saveFailed: 'Save failed: ',
  K.language: 'Language',
  K.languageDesc:
      'Switch the admin console display language (local only, not sent to clients).',
  K.appTitle: 'Chat Admin Console',
  K.appSubtitle: 'Chat Admin Console',
  K.loginAccount: 'Admin account',
  K.loginPassword: 'Password',
  K.loginSubmit: 'Sign in',
  K.loginHint: 'Default account admin / admin123',
  K.loginWelcome: 'Welcome back',
  K.loginSlogan:
      'Manage users, roles, discover pages and system settings in one place.',
  K.featUsers: 'Users',
  K.featRoles: 'Roles',
  K.featDiscover: 'Discover',
  K.featSettings: 'Settings',
  K.errorNetwork: 'Network error',
  K.errorNetworkRetry: 'Network error, please retry',
  K.navDashboard: 'Dashboard',
  K.navUsers: 'Users',
  K.navService: 'Support agents',
  K.navRoles: 'Roles',
  K.navAudit: 'Audit log',
  K.navAdmins: 'Admins',
  K.navDiscover: 'Discover columns',
  K.navSettings: 'Settings',
  K.adminConsole: 'Admin console',
  K.noModule: 'No module available',
  K.logout: 'Sign out',
  K.changePwd: 'Change password',
  K.pwdOld: 'Current password',
  K.pwdNew: 'New password',
  K.pwdConfirm: 'Confirm new password',
  K.pwdNewHint: 'At least 6 characters',
  K.pwdRequired: 'Please enter the current password',
  K.pwdTooShort: 'Password must be at least 6 characters',
  K.pwdMismatch: 'The two new passwords do not match',
  K.pwdSuccess: 'Password changed',
  K.saving: 'Saving...',
  K.saveConfig: 'Save configuration',
  K.reset: 'Reset',
  K.lastUpdated: 'Last updated: ',
  K.loadFailed: 'Failed to load: ',
  K.search: 'Search',
  K.dashTitle: 'Overview',
  K.dashUsers: 'Registered users',
  K.dashNewToday: 'New today',
  K.dashOnline: 'Online users',
  K.dashBanned: 'Banned users',
  K.dashTotalMsg: 'Total messages',
  K.dashTodayMsg: 'Messages today',
  K.dashGroups: 'Groups',
  K.dashFriendships: 'Friendships',
  K.dashSignupTrend: 'Signups (last {d} days)',
  K.dashMsgTrend: 'Messages (last {d} days)',
  K.auditSearchHint: 'Search action / operator',
  K.auditTotal: '{n} total',
  K.auditPage: 'Page {a} / {b}',
  K.colTime: 'Time',
  K.colOperator: 'Operator',
  K.colAction: 'Action',
  K.colTarget: 'Target',
  K.colDetail: 'Detail',
  K.edit: 'Edit',
  K.actions: 'Actions',
  K.pagerPage: 'Page {a} / {b}',
  K.userEditTitle: 'Edit user profile',
  K.userNickname: 'Nickname',
  K.userBanTitle: 'Ban user',
  K.userUnbanTitle: 'Unban user',
  K.userConfirmBan: 'Ban @{u}?',
  K.userConfirmUnban: 'Unban @{u}?',
  K.userReason: 'Reason (optional)',
  K.userBan: 'Ban',
  K.userUnban: 'Unban',
  K.userSearchHint: 'Search username / nickname',
  K.userTotal: '{n} users',
  K.userUsername: 'Username',
  K.userStatus: 'Status',
  K.userCreatedAt: 'Registered',
  K.userOnline: 'Online',
  K.userBanned: 'Banned',
  K.userOffline: 'Offline',
  K.delete: 'Delete',
  K.create: 'Create',
  K.enabled: 'Active',
  K.disabled: 'Disabled',
  K.permViewDashboard: 'View dashboard',
  K.permViewUsers: 'View users',
  K.permManageUsers: 'Manage users (edit/ban)',
  K.permViewRoles: 'View roles',
  K.permManageRoles: 'Manage roles',
  K.permViewAudit: 'View audit log',
  K.permViewAdmins: 'View admins',
  K.permManageAdmins: 'Manage admins',
  K.roleName: 'Role name',
  K.roleNewTitle: 'New role',
  K.roleEditTitle: 'Edit role',
  K.roleDesc: 'Description',
  K.rolePerms: 'Permissions',
  K.roleDeleteTitle: 'Delete role',
  K.roleConfirmDelete: 'Delete role "{n}"?',
  K.roleNoPerm: '(no permissions)',
  K.adminTitle: 'Admin accounts',
  K.adminNewTitle: 'New admin',
  K.adminUsername: 'Login',
  K.adminDisplayName: 'Display name',
  K.adminSubtitle: 'Role: {r}  ·  Created {d}',
  K.svcTitle: 'Support accounts',
  K.svcDesc:
      'Create multiple support accounts; users can pick an online agent to chat with directly from "Contact support" (no friendship required).',
  K.svcAdd: 'Add agent',
  K.svcNewTitle: 'New support account',
  K.svcMinChars3: 'At least 3 characters',
  K.svcNameRequired: 'Please enter a display name',
  K.svcLoginPwd: 'Password',
  K.svcCreated: 'Support account created',
  K.svcRemoveTitle: 'Remove support account',
  K.svcRemoveConfirm:
      'Remove "{n}" from support agents? The account stays as a regular user and past conversations are kept.',
  K.svcRemove: 'Remove',
  K.svcRemoved: 'Removed from support',
  K.svcRemoveFailed: 'Remove failed: ',
  K.svcEmpty: 'No support accounts yet — tap "Add agent" in the top right',
  K.svcRemoveAgent: 'Remove agent',
  K.discPinLimit: 'Up to {n} pinned columns — unpin another one first',
  K.discCreated: 'Added',
  K.discOpFailed: 'Operation failed: ',
  K.discConfirmDeleteTitle: 'Confirm delete',
  K.discConfirmDelete: 'Delete column "{n}"?',
  K.discDeleted: 'Deleted',
  K.discDeleteFailed: 'Delete failed: ',
  K.discAdd: 'Add column',
  K.discRefresh: 'Refresh',
  K.discEmpty: 'No columns yet',
  K.discPinned: 'Pinned',
  K.discHidden: 'Hidden',
  K.discUnpin: 'Unpin',
  K.discPin: 'Pin to bottom navigation',
  K.featOnline: 'Show online status',
  K.featOnlineDesc: 'Show online/offline badges on avatars and chat list',
  K.featVoiceCall: 'Enable voice calls',
  K.featVoiceCallDesc: 'Allow users to start one-to-one voice calls',
  K.featVideoCall: 'Enable video calls',
  K.featVideoCallDesc: 'Allow users to start one-to-one video calls',
  K.featFile: 'Allow sending files',
  K.featFileDesc: 'Show the file-sending entry in the chat input',
  K.featVoice: 'Allow sending voice messages',
  K.featVoiceDesc: 'Show the voice-recording entry in the chat input',
  K.featRegister: 'Allow user registration',
  K.featRegisterDesc: 'When off, regular users cannot self-register on the login page (admins only)',
  K.iceTitle: 'WebRTC real-time communication (STUN/TURN)',
  K.iceDesc: 'Configure the ICE servers used for voice/video calls. STUN alone is '
      'enough on the same network; for cross-network calls (e.g. mobile data vs '
      'Wi-Fi) a TURN relay is recommended. Leave empty to fall back to default STUN.',
  K.iceAdd: 'Add server',
  K.iceServer: 'Server {n}',
  K.iceUrls: 'URLs (comma separated)',
  K.iceUsername: 'Username (optional, TURN)',
  K.iceCredential: 'Credential (optional, TURN)',
  K.iceCredType: 'Credential type',
  K.iceCredPassword: 'Password (default)',
};

const _es = <String, String>{
  K.save: 'Guardar',
  K.saved: 'Guardado',
  K.retry: 'Reintentar',
  K.cancel: 'Cancelar',
  K.confirm: 'Guardar cambios',
  K.readOnly:
      'Su rol tiene acceso de solo lectura; no puede modificar la configuración.',
  K.saveFailed: 'Error al guardar: ',
  K.language: 'Idioma',
  K.languageDesc:
      'Cambia el idioma de la consola de administración (solo local, no se envía a los clientes).',
  K.appTitle: 'Consola de administración de chat',
  K.appSubtitle: 'Chat Admin Console',
  K.loginAccount: 'Cuenta de administrador',
  K.loginPassword: 'Contraseña',
  K.loginSubmit: 'Iniciar sesión',
  K.loginHint: 'Cuenta predeterminada admin / admin123',
  K.loginWelcome: 'Bienvenido de nuevo',
  K.loginSlogan:
      'Gestione usuarios, roles, páginas de descubrimiento y ajustes del sistema en un solo lugar.',
  K.featUsers: 'Usuarios',
  K.featRoles: 'Roles',
  K.featDiscover: 'Descubrir',
  K.featSettings: 'Ajustes',
  K.errorNetwork: 'Error de red',
  K.errorNetworkRetry: 'Error de red, inténtelo de nuevo',
  K.navDashboard: 'Panel',
  K.navUsers: 'Usuarios',
  K.navService: 'Agentes de soporte',
  K.navRoles: 'Roles',
  K.navAudit: 'Registro de auditoría',
  K.navAdmins: 'Administradores',
  K.navDiscover: 'Columnas de descubrimiento',
  K.navSettings: 'Ajustes',
  K.adminConsole: 'Consola de administración',
  K.noModule: 'No hay módulos disponibles',
  K.logout: 'Cerrar sesión',
  K.changePwd: 'Cambiar contraseña',
  K.pwdOld: 'Contraseña actual',
  K.pwdNew: 'Nueva contraseña',
  K.pwdConfirm: 'Confirmar nueva contraseña',
  K.pwdNewHint: 'Mínimo 6 caracteres',
  K.pwdRequired: 'Introduzca la contraseña actual',
  K.pwdTooShort: 'La contraseña debe tener al menos 6 caracteres',
  K.pwdMismatch: 'Las contraseñas nuevas no coinciden',
  K.pwdSuccess: 'Contraseña actualizada',
  K.saving: 'Guardando...',
  K.saveConfig: 'Guardar configuración',
  K.reset: 'Restablecer',
  K.lastUpdated: 'Última actualización: ',
  K.loadFailed: 'Error al cargar: ',
  K.search: 'Buscar',
  K.dashTitle: 'Resumen',
  K.dashUsers: 'Usuarios registrados',
  K.dashNewToday: 'Nuevos hoy',
  K.dashOnline: 'Usuarios en línea',
  K.dashBanned: 'Usuarios bloqueados',
  K.dashTotalMsg: 'Mensajes totales',
  K.dashTodayMsg: 'Mensajes hoy',
  K.dashGroups: 'Grupos',
  K.dashFriendships: 'Amistades',
  K.dashSignupTrend: 'Registros (últimos {d} días)',
  K.dashMsgTrend: 'Mensajes (últimos {d} días)',
  K.auditSearchHint: 'Buscar acción / operador',
  K.auditTotal: '{n} en total',
  K.auditPage: 'Página {a} / {b}',
  K.colTime: 'Hora',
  K.colOperator: 'Operador',
  K.colAction: 'Acción',
  K.colTarget: 'Objetivo',
  K.colDetail: 'Detalle',
  K.edit: 'Editar',
  K.actions: 'Acciones',
  K.pagerPage: 'Página {a} / {b}',
  K.userEditTitle: 'Editar perfil de usuario',
  K.userNickname: 'Apodo',
  K.userBanTitle: 'Bloquear usuario',
  K.userUnbanTitle: 'Desbloquear usuario',
  K.userConfirmBan: '¿Bloquear a @{u}?',
  K.userConfirmUnban: '¿Desbloquear a @{u}?',
  K.userReason: 'Motivo (opcional)',
  K.userBan: 'Bloquear',
  K.userUnban: 'Desbloquear',
  K.userSearchHint: 'Buscar nombre de usuario / apodo',
  K.userTotal: '{n} usuarios',
  K.userUsername: 'Nombre de usuario',
  K.userStatus: 'Estado',
  K.userCreatedAt: 'Registro',
  K.userOnline: 'En línea',
  K.userBanned: 'Bloqueado',
  K.userOffline: 'Desconectado',
  K.delete: 'Eliminar',
  K.create: 'Crear',
  K.enabled: 'Activo',
  K.disabled: 'Desactivado',
  K.permViewDashboard: 'Ver panel',
  K.permViewUsers: 'Ver usuarios',
  K.permManageUsers: 'Gestionar usuarios (editar/bloquear)',
  K.permViewRoles: 'Ver roles',
  K.permManageRoles: 'Gestionar roles',
  K.permViewAudit: 'Ver registro de auditoría',
  K.permViewAdmins: 'Ver administradores',
  K.permManageAdmins: 'Gestionar administradores',
  K.roleName: 'Nombre del rol',
  K.roleNewTitle: 'Nuevo rol',
  K.roleEditTitle: 'Editar rol',
  K.roleDesc: 'Descripción',
  K.rolePerms: 'Permisos',
  K.roleDeleteTitle: 'Eliminar rol',
  K.roleConfirmDelete: '¿Eliminar el rol «{n}»?',
  K.roleNoPerm: '(sin permisos)',
  K.adminTitle: 'Cuentas de administrador',
  K.adminNewTitle: 'Nuevo administrador',
  K.adminUsername: 'Usuario',
  K.adminDisplayName: 'Nombre visible',
  K.adminSubtitle: 'Rol: {r}  ·  Creado {d}',
  K.svcTitle: 'Cuentas de soporte',
  K.svcDesc:
      'Cree varias cuentas de soporte; los usuarios pueden elegir un agente en línea desde «Contactar soporte» (sin necesidad de amistad).',
  K.svcAdd: 'Añadir agente',
  K.svcNewTitle: 'Nueva cuenta de soporte',
  K.svcMinChars3: 'Mínimo 3 caracteres',
  K.svcNameRequired: 'Introduzca un nombre visible',
  K.svcLoginPwd: 'Contraseña',
  K.svcCreated: 'Cuenta de soporte creada',
  K.svcRemoveTitle: 'Eliminar cuenta de soporte',
  K.svcRemoveConfirm:
      '¿Eliminar a «{n}» de los agentes de soporte? La cuenta seguirá existiendo como usuario normal y no se perderán las conversaciones.',
  K.svcRemove: 'Eliminar',
  K.svcRemoved: 'Eliminado de soporte',
  K.svcRemoveFailed: 'Error al eliminar: ',
  K.svcEmpty: 'Aún no hay cuentas de soporte: toque «Añadir agente» arriba a la derecha',
  K.svcRemoveAgent: 'Eliminar agente',
  K.discPinLimit: 'Máximo {n} columnas fijadas: quite la fijación de otra primero',
  K.discCreated: 'Añadido',
  K.discOpFailed: 'Error en la operación: ',
  K.discConfirmDeleteTitle: 'Confirmar eliminación',
  K.discConfirmDelete: '¿Eliminar la columna «{n}»?',
  K.discDeleted: 'Eliminado',
  K.discDeleteFailed: 'Error al eliminar: ',
  K.discAdd: 'Añadir columna',
  K.discRefresh: 'Actualizar',
  K.discEmpty: 'Aún no hay columnas',
  K.discPinned: 'Fijada',
  K.discHidden: 'Ocultada',
  K.discUnpin: 'Quitar fijación',
  K.discPin: 'Fijar en la navegación inferior',
  K.featOnline: 'Mostrar estado en línea',
  K.featOnlineDesc: 'Mostrar indicadores en línea/desconectado en avatares y lista de chats',
  K.featVoiceCall: 'Habilitar llamadas de voz',
  K.featVoiceCallDesc: 'Permitir a los usuarios iniciar llamadas de voz uno a uno',
  K.featVideoCall: 'Habilitar videollamadas',
  K.featVideoCallDesc: 'Permitir a los usuarios iniciar videollamadas uno a uno',
  K.featFile: 'Permitir envío de archivos',
  K.featFileDesc: 'Mostrar la opción de enviar archivos en el chat',
  K.featVoice: 'Permitir envío de voz',
  K.featVoiceDesc: 'Mostrar la opción de grabar voz en el chat',
  K.featRegister: 'Permitir registro de usuarios',
  K.featRegisterDesc: 'Si se desactiva, los usuarios normales no podrán registrarse desde la página de inicio de sesión (solo administradores)',
  K.iceTitle: 'Comunicación en tiempo real WebRTC (STUN/TURN)',
  K.iceDesc: 'Configure los servidores ICE usados para las llamadas de voz/vídeo. '
      'Con solo STUN basta en la misma red; para llamadas entre redes (p. ej. datos '
      'móviles frente a Wi-Fi) se recomienda un relay TURN. Déjelo vacío para usar el STUN predeterminado.',
  K.iceAdd: 'Añadir servidor',
  K.iceServer: 'Servidor {n}',
  K.iceUrls: 'URL (separadas por comas)',
  K.iceUsername: 'Usuario (opcional, TURN)',
  K.iceCredential: 'Credencial (opcional, TURN)',
  K.iceCredType: 'Tipo de credencial',
  K.iceCredPassword: 'Contraseña (predeterminada)',
};

final Map<AppLocale, Map<String, String>> _tables = {
  AppLocale.zhHant: _zhHant,
  AppLocale.zhHans: _zhHans,
  AppLocale.en: _en,
  AppLocale.es: _es,
};

/// 當前語言的文案讀取器。
///
/// 用法：`final t = context.watch<LocaleProvider>().t;` → `t[K.appTitle]`。
/// 某語言缺失的 key 自動回落到繁體中文，都不存在時返回 key 本身，
/// 保證新增語言/文案時界面不會出現空白或崩潰。
class Strings {
  const Strings(this.locale);

  final AppLocale locale;

  String operator [](String key) =>
      _tables[locale]?[key] ?? _zhHant[key] ?? key;

  /// 帶佔位符的文案：`t.tr(K.auditTotal, {'n': '12'})`。
  /// 文案中用 `{n}` 形式書寫佔位符。
  String tr(String key, [Map<String, String> args = const {}]) {
    var s = this[key];
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
    return s;
  }
}
