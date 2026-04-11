---
name: team:qi-framework
description: Qi 框架开发规范 — 基于 Gin 的生产级 Go Web 框架，统一响应、业务错误、泛型绑定、OpenAPI 文档
---

# Qi 框架开发规范

Qi (`github.com/tokmz/qi`) 是基于 Gin 的 Go Web 框架，提供统一响应封装、业务错误系统、泛型请求绑定、自动 OpenAPI 3.0 文档生成、请求日志、链路追踪等生产级能力。

## 快速识别

项目使用 Qi 框架的特征：
- `go.mod` 中有 `github.com/tokmz/qi`
- 代码中有 `qi.New()` 或 `qi.Context`
- 响应格式为 `{"code": 0, "message": "success", "data": {}, "trace_id": "..."}`

## 核心特性

| 特性 | 说明 |
|------|------|
| 统一响应封装 | 所有响应走同一 JSON 结构，自动填充 `trace_id` |
| 业务错误系统 | 预定义错误码，不可变克隆链，Code + HTTP Status 分离 |
| 泛型请求绑定 | `Bind` / `BindR` / `BindE` / `BindRE` 自动完成请求绑定 + 响应包装 |
| OpenAPI 3.0 | 基于类型反射，注册路由时同步生成文档，内置 Swagger UI |
| 请求日志 | 基于 zap，记录方法/路径/状态码/耗时/IP/trace_id |
| 链路追踪 | 集成 OpenTelemetry，支持 OTLP gRPC/HTTP，自动注入 `trace_id` |
| 多级缓存 | 内存 LRU + Redis，防穿透/击穿/雪崩，分布式锁 |
| 数据库 | GORM 封装，读写分离，连接池，zap 日志接入 |

## 项目初始化

```go
package main

import "github.com/tokmz/qi"

func main() {
    app := qi.New(
        qi.WithAddr(":8080"),
        qi.WithMode("release"),
        qi.WithLogger(&qi.LoggerConfig{
            SkipPaths: []string{"/ping", "/health"},
        }),
        qi.WithTracing(&qi.TracingConfig{
            ServiceName: "user-service",
            Exporter:    qi.TracingExporterOTLPGRPC,
            Endpoint:    "otel-collector:4317",
            Insecure:    true,
            SampleRate:  0.1,
        }),
        qi.WithOpenAPI(&qi.OpenAPIConfig{
            Title:     "User API",
            Version:   "1.0.0",
            SwaggerUI: "/docs",
        }),
    )

    // 注册路由
    setupRoutes(app)

    // 启动服务（自动优雅关闭）
    app.Run()
}
```

## 分层架构（Qi 适配）

Qi 框架遵循标准分层架构，但有特定的实现方式：

```
Handler（HTTP 层） → Service（业务层） → Repository（数据层） → Model（模型层）
```

### Handler 层（使用 Qi Context）

```go
// 方式 1：泛型绑定（推荐）
app.POST("/users", qi.Bind[CreateUserReq, User](createUser))

func createUser(c *qi.Context, req *CreateUserReq) (*User, error) {
    user, err := userService.Create(c, req)
    if err != nil {
        return nil, err  // 自动调用 c.Fail()
    }
    return user, nil  // 自动调用 c.OK()
}

// 方式 2：手动处理
app.POST("/users", func(c *qi.Context) {
    var req CreateUserReq
    if err := c.ShouldBindJSON(&req); err != nil {
        c.Fail(qi.ErrInvalidParams.WithErr(err))
        return
    }
    
    user, err := userService.Create(c, &req)
    if err != nil {
        c.Fail(err)
        return
    }
    
    c.OK(user, "创建成功")
})
```

### Service 层（标准实现）

```go
type UserService interface {
    Create(ctx context.Context, req *CreateUserReq) (*User, error)
    GetByID(ctx context.Context, id int64) (*User, error)
}

type userService struct {
    repo UserRepository
}

func (s *userService) Create(ctx context.Context, req *CreateUserReq) (*User, error) {
    // 业务校验
    if err := s.validateUser(req); err != nil {
        return nil, errors.ErrInvalidParams.WithMessage(err.Error())
    }
    
    // 调用 Repository
    user := &User{Name: req.Name, Email: req.Email}
    if err := s.repo.Create(ctx, user); err != nil {
        return nil, errors.ErrServer.WithErr(err)
    }
    
    return user, nil
}
```

### Repository 层（使用 Qi 数据库封装）

```go
import "github.com/tokmz/qi/pkg/database"

type UserRepository interface {
    Create(ctx context.Context, user *User) error
    FindByID(ctx context.Context, id int64) (*User, error)
}

type userRepository struct {
    db *database.DB
}

func (r *userRepository) Create(ctx context.Context, user *User) error {
    return r.db.WithContext(ctx).Create(user).Error
}

func (r *userRepository) FindByID(ctx context.Context, id int64) (*User, error) {
    var user User
    err := r.db.WithContext(ctx).First(&user, id).Error
    return &user, err
}
```

## 响应规范

### 统一响应格式

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

### 响应方法

```go
// 成功响应
c.OK(data)                    // code=0, message="success"
c.OK(data, "创建成功")          // code=0, 自定义 message

// 失败响应
c.Fail(qi.ErrNotFound)        // 使用预定义错误
c.Fail(customErr)             // 使用自定义错误
c.FailWithCode(1001, 400, "参数错误")  // 直接指定 code/status/message

// 分页响应
c.Page(total, list)           // 自动包装为 {total, list}
```

## 业务错误系统

### 使用预定义错误

```go
import "github.com/tokmz/qi/pkg/errors"

// Qi 预定义错误
qi.ErrServer          // 1000, 500
qi.ErrBadRequest      // 1001, 400
qi.ErrUnauthorized    // 1002, 401
qi.ErrForbidden       // 1003, 403
qi.ErrNotFound        // 1004, 404
qi.ErrConflict        // 1005, 409
qi.ErrTooManyRequests // 1006, 429
qi.ErrInvalidParams   // 1100, 400
qi.ErrMissingParams   // 1101, 400
qi.ErrInvalidFormat   // 1102, 400
qi.ErrOutOfRange      // 1103, 400
```

### 定义自定义错误

```go
import "github.com/tokmz/qi/pkg/errors"

// 定义哨兵错误（不可变）
var (
    ErrUserNotFound     = errors.NewWithStatus(2001, 404, "user not found")
    ErrUserExists       = errors.NewWithStatus(2002, 409, "user already exists")
    ErrInvalidPassword  = errors.NewWithStatus(2003, 400, "invalid password")
)

// 使用克隆链（不污染原始哨兵）
func (s *userService) GetByID(ctx context.Context, id int64) (*User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrUserNotFound.
                WithErr(err).
                WithMessage(fmt.Sprintf("用户 ID %d 不存在", id))
        }
        return nil, qi.ErrServer.WithErr(err)
    }
    return user, nil
}
```

## 泛型请求绑定

### Bind[Req, Resp] - 有请求体，有响应体

```go
app.POST("/users", qi.Bind[CreateUserReq, User](createUser))

func createUser(c *qi.Context, req *CreateUserReq) (*User, error) {
    // 自动绑定请求
    // 自动包装响应
    return userService.Create(c, req)
}
```

### BindR[Resp] - 无请求体，有响应体

```go
app.GET("/users", qi.BindR[[]User](listUsers))

func listUsers(c *qi.Context) ([]User, error) {
    return userService.List(c)
}
```

### BindE[Req] - 有请求体，无响应体

```go
app.DELETE("/users/:id", qi.BindE[DeleteUserReq](deleteUser))

func deleteUser(c *qi.Context, req *DeleteUserReq) error {
    return userService.Delete(c, req.ID)
}
```

### BindRE - 无请求体，无响应体

```go
app.POST("/cache/flush", qi.BindRE(clearCache))

func clearCache(c *qi.Context) error {
    return cacheService.Flush(c)
}
```

## 路由注册与 OpenAPI

### 基础路由

```go
app.GET("/ping", func(c *qi.Context) {
    c.OK("pong")
})
```

### 路由分组 + 中间件

```go
v1 := app.Group("/api/v1")
v1.Use(authMiddleware())

v1.GET("/users", listUsers)
v1.POST("/users", createUser)
```

### 链式 API（自动生成 OpenAPI 文档）

```go
v1.API().
    POST("/users", qi.Bind[CreateUserReq, User](createUser)).
    Summary("创建用户").
    Description("创建新用户账号").
    Tags("用户管理").
    OperationID("createUser").
    Done()

v1.API().
    GET("/users/:id", qi.BindR[User](getUser)).
    Summary("获取用户").
    Tags("用户管理").
    Done()
```

## 中间件

### 鉴权中间件

```go
func AuthMiddleware() qi.HandlerFunc {
    return func(c *qi.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.Fail(qi.ErrUnauthorized)
            c.Abort()
            return
        }
        
        userID, err := parseToken(token)
        if err != nil {
            c.Fail(qi.ErrUnauthorized.WithErr(err))
            c.Abort()
            return
        }
        
        c.Set("user_id", userID)
        c.Next()
    }
}
```

### 操作日志中间件（利用路由元信息）

```go
func OperationLogMiddleware(e *qi.Engine) qi.HandlerFunc {
    return func(c *qi.Context) {
        c.Next()
        
        // 查询路由元信息
        meta := e.RouteMeta(c.Request().Method, c.FullPath())
        if meta != nil && meta.Summary != "" {
            log.Printf("操作：%s, 用户：%v, trace_id：%s",
                meta.Summary,
                c.Get("user_id"),
                c.GetString("trace_id"),
            )
        }
    }
}
```

## 缓存使用

```go
import "github.com/tokmz/qi/pkg/cache"

// 初始化缓存
c, err := cache.New(&cache.Config{
    Driver:    cache.DriverMultiLevel,
    KeyPrefix: "app:",
    Memory:    &cache.MemoryConfig{MaxSize: 5_000},
    Redis:     &cache.RedisConfig{Addr: "127.0.0.1:6379"},
    Penetration: &cache.PenetrationConfig{
        EnableBloom: true,
        BloomN:      100_000,
        NullTTL:     60 * time.Second,
    },
    TracingEnabled: true,
})

// 基础操作
c.Set(ctx, "user:1", user, time.Hour)
var u User
c.Get(ctx, "user:1", &u)

// 防击穿（自动 singleflight）
c.GetOrSet(ctx, "user:1", &u, time.Hour, func() (any, error) {
    return userRepo.FindByID(ctx, 1)
})

// 分布式锁
locker, _ := cache.NewLocker(&cache.RedisConfig{Addr: "127.0.0.1:6379"}, "app:")
unlock, _ := locker.Lock(ctx, "order:create", 10*time.Second)
defer unlock()
```

## 数据库使用

```go
import "github.com/tokmz/qi/pkg/database"

// 初始化数据库
db, err := database.New(&database.Config{
    Type:           database.MySQL,
    DSN:            "user:pass@tcp(localhost:3306)/app?parseTime=True",
    ZapLogger:      zapLogger,
    TracingEnabled: true,
    ReadWriteSplit: &database.ReadWriteSplitConfig{
        Replicas: []string{"user:pass@tcp(replica:3306)/app?parseTime=True"},
        Policy:   "round_robin",
    },
})

// 使用（标准 GORM API）
db.WithContext(ctx).Create(&user)
db.WithContext(ctx).First(&user, id)
db.WithContext(ctx).Where("email = ?", email).Find(&users)
```

## 测试规范

### Handler 测试

```go
func TestCreateUser(t *testing.T) {
    app := qi.New()
    app.POST("/users", qi.Bind[CreateUserReq, User](createUser))
    
    w := httptest.NewRecorder()
    req := httptest.NewRequest("POST", "/users", strings.NewReader(`{"name":"test"}`))
    req.Header.Set("Content-Type", "application/json")
    
    app.ServeHTTP(w, req)
    
    if w.Code != 200 {
        t.Errorf("expected 200, got %d", w.Code)
    }
    
    var resp qi.Response
    json.Unmarshal(w.Body.Bytes(), &resp)
    if resp.Code != 0 {
        t.Errorf("expected code 0, got %d", resp.Code)
    }
}
```

### Service 测试（Mock Repository）

```go
type mockUserRepo struct {
    createFunc func(ctx context.Context, user *User) error
}

func (m *mockUserRepo) Create(ctx context.Context, user *User) error {
    return m.createFunc(ctx, user)
}

func TestUserService_Create(t *testing.T) {
    repo := &mockUserRepo{
        createFunc: func(ctx context.Context, user *User) error {
            user.ID = 1
            return nil
        },
    }
    
    svc := &userService{repo: repo}
    user, err := svc.Create(context.Background(), &CreateUserReq{Name: "test"})
    
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.ID != 1 {
        t.Errorf("expected ID 1, got %d", user.ID)
    }
}
```

## 最佳实践

### 1. 优先使用泛型绑定

```go
// ✅ 推荐：类型安全，自动生成 OpenAPI
app.POST("/users", qi.Bind[CreateUserReq, User](createUser))

// ❌ 不推荐：手动绑定，容易出错
app.POST("/users", func(c *qi.Context) {
    var req CreateUserReq
    c.ShouldBindJSON(&req)
    // ...
})
```

### 2. 使用链式 API 注册路由

```go
// ✅ 推荐：自动生成完整的 OpenAPI 文档
v1.API().
    POST("/users", qi.Bind[CreateUserReq, User](createUser)).
    Summary("创建用户").
    Tags("用户管理").
    Done()

// ❌ 不推荐：文档不完整
v1.POST("/users", qi.Bind[CreateUserReq, User](createUser))
```

### 3. 错误使用克隆链

```go
// ✅ 推荐：不污染哨兵错误
return nil, ErrUserNotFound.WithErr(err).WithMessage("用户不存在")

// ❌ 禁止：直接修改哨兵错误
ErrUserNotFound.Message = "用户不存在"  // 会影响所有使用该错误的地方
```

### 4. Context 传递

```go
// ✅ 推荐：使用 qi.Context（实现了 context.Context）
func (s *userService) Create(ctx context.Context, req *CreateUserReq) (*User, error) {
    return s.repo.Create(ctx, &User{Name: req.Name})
}

// ❌ 不推荐：传递整个 qi.Context 到 Service 层
func (s *userService) Create(c *qi.Context, req *CreateUserReq) (*User, error) {
    // Service 层不应该依赖 HTTP 层
}
```

### 5. 启用链路追踪和日志

```go
// ✅ 推荐：生产环境必须启用
app := qi.New(
    qi.WithLogger(&qi.LoggerConfig{}),
    qi.WithTracing(&qi.TracingConfig{
        ServiceName: "user-service",
        Exporter:    qi.TracingExporterOTLPGRPC,
        Endpoint:    "otel-collector:4317",
    }),
)

// ❌ 不推荐：生产环境不启用追踪
app := qi.New()  // 无法追踪问题
```

## 项目结构示例

```
project/
├── cmd/
│   └── server/
│       └── main.go           # 入口，初始化 qi.Engine
├── internal/
│   ├── handler/              # HTTP 层
│   │   ├── user.go           # 用户相关 handler
│   │   └── order.go
│   ├── service/              # 业务层
│   │   ├── user.go
│   │   └── order.go
│   ├── repository/           # 数据层
│   │   ├── user.go
│   │   └── order.go
│   ├── model/                # 模型层
│   │   ├── user.go
│   │   └── order.go
│   ├── middleware/           # 中间件
│   │   ├── auth.go
│   │   └── log.go
│   └── errors/               # 自定义错误
│       └── errors.go
├── config/
│   └── config.yaml
├── migrations/               # 数据库迁移
│   └── 001_init.sql
├── go.mod
└── go.sum
```

## 与其他框架的区别

| 特性 | Qi | Gin | Echo | Fiber |
|------|----|----|------|-------|
| 统一响应封装 | ✅ 内置 | ❌ 手动 | ❌ 手动 | ❌ 手动 |
| 业务错误系统 | ✅ 内置 | ❌ 手动 | ❌ 手动 | ❌ 手动 |
| 泛型请求绑定 | ✅ 内置 | ❌ 无 | ❌ 无 | ❌ 无 |
| OpenAPI 自动生成 | ✅ 内置 | ❌ 需第三方 | ❌ 需第三方 | ❌ 需第三方 |
| 链路追踪 | ✅ 内置 | ❌ 手动 | ❌ 手动 | ❌ 手动 |
| 多级缓存 | ✅ 内置 | ❌ 无 | ❌ 无 | ❌ 无 |
| 数据库封装 | ✅ 内置 | ❌ 无 | ❌ 无 | ❌ 无 |

## 协作接口

- 接收 ← `architect`: 架构设计文档 + 接口定义
- 输出 → `reviewer`: 提交 PR 待审核
- 输出 → `frontend`: OpenAPI 文档（访问 `/docs` 查看）
- 接收 ← `reviewer`: 代码审核反馈，修改后重新提交
