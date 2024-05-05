const std = @import("std");
const rl = @import("raylib");
const rm = @import("raylib-math");
const V2 = rl.Vector2;

const SCREEN_WIDTH: f32 = 1280;
const SCREEN_HEIGHT: f32 = 800;

const FONT_SIZE: i32 = 20;

const BRICK_W: f32 = 120;
const BRICK_H: f32 = 30;
const BRICK_SPACING: f32 = 20;
const BRICK_LINES: f32 = 7;
const BRICKS_PER_LINE: f32 = 9;

const PLAYER_HEIGHT: f32 = 10;

const BALL_RADIUS: f32 = 5;
const MAX_BALLS: i32 = 3;

const GAME_SPEED: f32 = 3;

var prng: std.rand.DefaultPrng = undefined;

const PlayerWidth = enum {
    SMALL,
    NORMAL,
    LARGE,

    fn width(self: @This()) f32 {
        return switch (self) {
            .SMALL => 50.0,
            .NORMAL => 100.0,
            .LARGE => 150.0,
        };
    }
};

const Player = struct {
    pos: V2,
    w: PlayerWidth,

    fn init(width: PlayerWidth) Player {
        return Player{
            .pos = V2.init(
                SCREEN_WIDTH / 2 - width.width() / 2,
                SCREEN_HEIGHT - 50,
            ),
            .w = width,
        };
    }
    fn speed(self: @This()) f32 {
        return switch (self.w) {
            .SMALL => 7.5 * GAME_SPEED,
            .NORMAL => 5 * GAME_SPEED,
            .LARGE => 2.5 * GAME_SPEED,
        };
    }
    fn update(self: *@This(), state: *const State) void {
        if (rl.isKeyDown(rl.KeyboardKey.key_a) and state.player.pos.x > 3) {
            self.pos.x -= self.speed();
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_d) and
            self.pos.x < SCREEN_WIDTH - self.w.width() - 3)
        {
            self.pos.x += self.speed();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_j)) {
            self.w = switch (self.w) {
                .SMALL => .NORMAL,
                .NORMAL => .LARGE,
                .LARGE => .SMALL,
            };
            const width = self.w.width();
            if (self.pos.x < 0) {
                self.pos.x = 0;
            } else if (self.pos.x + width > SCREEN_WIDTH) {
                self.pos.x = SCREEN_WIDTH - width;
            }
        }
    }

    fn draw(self: @This()) void {
        rl.drawRectangleV(
            self.pos,
            V2.init(self.w.width(), PLAYER_HEIGHT),
            rl.Color.green,
        );
    }
};

const Brick = struct {
    pos: V2,
    size: V2,
    c: rl.Color,
    active: bool,

    const CollisionSide = enum {
        TOP,
        LEFT,
        RIGHT,
        BOTTOM,
    };

    fn update(self: *@This(), state: *State) bool {
        if (!state.ball.active or !self.active) {
            return true;
        }
        if (self.getCollision(state)) |side| {
            self.active = false;
            rl.playSound(state.sound_brick_hit);
            switch (side) {
                .TOP, .BOTTOM => state.ball.velocity.y = -state.ball.velocity.y,
                .LEFT, .RIGHT => state.ball.velocity.x = -state.ball.velocity.x,
            }
            return false;
        }
        return true;
    }
    fn draw(self: @This()) void {
        if (self.active) {
            rl.drawRectangleV(self.pos, self.size, self.c);
        }
    }
    fn getCollision(self: @This(), state: *const State) ?CollisionSide {
        const bp = state.ball.pos;
        const bv = state.ball.velocity;

        if (!rl.checkCollisionCircleRec(bp, BALL_RADIUS, rl.Rectangle.init(
            self.pos.x,
            self.pos.y,
            self.size.x,
            self.size.y,
        ))) {
            return null;
        }
        if (bv.x > 0 and bp.x <= self.pos.x) {
            return .LEFT;
        } else if (bv.x < 0 and bp.x - BALL_RADIUS >= self.pos.x + BRICK_W) {
            return .RIGHT;
        } else if (bv.y < 0 and bp.y >= self.pos.y + BRICK_H) {
            return .BOTTOM;
        }
        return .TOP;
    }
};

const Ball = struct {
    pos: V2,
    velocity: V2,
    active: bool,

    fn init() Ball {
        return Ball{
            .pos = undefined,
            .velocity = undefined,
            .active = false,
        };
    }
    fn spawn(self: *@This(), state: *const State) void {
        if (self.active == false) {
            self.pos.x = state.player.pos.x + state.player.w.width() / 2;
            self.pos.y = state.player.pos.y;
            var xvel: f32 = (state.rand.float(f32) - 0.5) * 4 * GAME_SPEED;
            if (xvel < 0 and xvel > -2) {
                xvel = -2;
            } else if (xvel > 0 and xvel < 2) {
                xvel = 2;
            }
            self.velocity = V2.init(xvel, -3 * GAME_SPEED);
            self.active = true;
        }
    }
    fn update(self: *@This(), state: *const State) bool {
        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            self.spawn(state);
            return true;
        }
        if (!self.active) {
            return true;
        }
        self.pos = rm.vector2Add(self.pos, self.velocity);
        if (self.pos.x < 0) {
            self.pos.x = 0;
            self.velocity.x = -self.velocity.x;
        } else if (self.pos.x > SCREEN_WIDTH - BALL_RADIUS) {
            self.pos.x = SCREEN_WIDTH - BALL_RADIUS;
            self.velocity.x = -self.velocity.x;
        } else if (self.pos.y < 0) {
            self.pos.y = 0;
            self.velocity.y = -self.velocity.y;
        } else if (self.pos.y >= state.player.pos.y and
            self.pos.x >= state.player.pos.x and
            self.pos.x <= state.player.pos.x + state.player.w.width())
        {
            rl.playSound(state.sound_player_hit);
            self.pos.y = state.player.pos.y - BALL_RADIUS;
            self.velocity.y = -self.velocity.y;
        } else if (self.pos.y > SCREEN_HEIGHT - BALL_RADIUS) {
            self.active = false;
            return false;
        }
        return true;
    }
    fn draw(self: @This()) void {
        if (self.active) {
            rl.drawCircleV(self.pos, BALL_RADIUS, rl.Color.white);
        }
    }
};

const GameEnding = enum {
    WIN,
    LOOSE,
};

const State = struct {
    rand: std.Random,
    bricks: std.ArrayList(Brick),
    player: Player,
    ball: Ball,
    ending: ?GameEnding,
    balls_lost: i32,
    sound_brick_hit: rl.Sound,
    sound_player_hit: rl.Sound,
    sound_ball_lost: rl.Sound,
    sound_win: rl.Sound,
    sound_loose: rl.Sound,

    fn init(allocator: std.mem.Allocator, rand: std.Random) !State {
        const bricks = try makeBricks(allocator);
        const player = Player.init(.NORMAL);
        const ball = Ball.init();

        return State{
            .rand = rand,
            .bricks = bricks,
            .player = player,
            .ball = ball,
            .ending = null,
            .balls_lost = 0,
            .sound_brick_hit = undefined,
            .sound_player_hit = undefined,
            .sound_ball_lost = undefined,
            .sound_win = undefined,
            .sound_loose = undefined,
        };
    }
    fn deinit(self: @This()) void {
        self.bricks.deinit();
    }
    fn update(self: *@This()) void {
        self.player.update(self);
        if (!self.ball.update(self)) {
            self.balls_lost += 1;
            if (self.balls_lost == MAX_BALLS) {
                self.updateEnding();
            } else {
                rl.playSound(self.sound_ball_lost);
            }
        }
        for (self.bricks.items) |*brick| {
            if (!brick.update(self)) {
                self.updateEnding();
            }
        }
    }
    fn draw(self: @This()) void {
        for (self.bricks.items) |brick| {
            brick.draw();
        }
        self.player.draw();
        self.ball.draw();
    }
    fn updateEnding(self: *@This()) void {
        if (self.win()) {
            self.ending = .WIN;
            rl.playSound(self.sound_win);
        } else if (self.balls_lost == MAX_BALLS) {
            self.ending = .LOOSE;
            rl.playSound(self.sound_loose);
        }
    }
    fn win(self: @This()) bool {
        for (self.bricks.items) |brick| {
            if (brick.active) {
                return false;
            }
        }
        return true;
    }
};

fn makeBricks(allocator: std.mem.Allocator) !std.ArrayList(Brick) {
    var al = std.ArrayList(Brick).init(allocator);
    var line: f32 = 0;
    while (line < BRICK_LINES) : (line += 1) {
        var i: f32 = 0;
        while (i < BRICKS_PER_LINE) : (i += 1) {
            const b = Brick{
                .pos = V2.init(
                    BRICK_SPACING + i * (BRICK_W + BRICK_SPACING),
                    BRICK_SPACING + line * (BRICK_H + BRICK_SPACING),
                ),
                .size = V2.init(BRICK_W, BRICK_H),
                .c = rl.Color.red,
                .active = true,
            };
            try al.append(b);
        }
    }
    return al;
}

fn draw(state: *State) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    if (state.ending != null) switch (state.ending.?) {
        .WIN => {
            rl.drawText(
                "YOU WIN!",
                SCREEN_WIDTH / 2 - 200,
                SCREEN_HEIGHT / 2 - 20,
                FONT_SIZE * 4,
                rl.Color.yellow,
            );
        },
        .LOOSE => {
            rl.drawText(
                "YOU LOOSE!",
                SCREEN_WIDTH / 2 - 200,
                SCREEN_HEIGHT / 2 - 20,
                FONT_SIZE * 4,
                rl.Color.yellow,
            );
        },
    } else {
        rl.drawText(
            "zbreakout",
            SCREEN_WIDTH / 2 - 50,
            SCREEN_HEIGHT / 2 - 20,
            FONT_SIZE,
            rl.Color.light_gray,
        );
    }
    state.draw();
    drawBallsLeft(state);
}

fn drawBallsLeft(state: *const State) void {
    const ish: i32 = @intFromFloat(SCREEN_HEIGHT);
    const ibs: i32 = @intFromFloat(BRICK_SPACING);
    var ibr: i32 = @intFromFloat(BALL_RADIUS);
    ibr *= 2;
    var x: i32 = ibs;

    var i: i32 = state.balls_lost;
    while (i < MAX_BALLS) : (i += 1) {
        rl.drawCircle(x + i, ish - ibr * 2, BALL_RADIUS * 2, rl.Color.lime);
        x += ibr + ibs;
    }
}

fn gameLoop(state: *State) void {
    while (!rl.windowShouldClose()) {
        if (state.ending == null) {
            state.update();
        }
        draw(state);
    }
}

fn initRandom() !std.Random {
    prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    return prng.random();
}

fn loadSounds(state: *State) void {
    state.sound_brick_hit = rl.loadSound("assets/sound/brick_hit.wav");
    state.sound_player_hit = rl.loadSound("assets/sound/player_hit.wav");
    state.sound_ball_lost = rl.loadSound("assets/sound/ball_lost.wav");
    state.sound_win = rl.loadSound("assets/sound/win.wav");
    state.sound_loose = rl.loadSound("assets/sound/loose.wav");
}

fn unloadSounds(state: *const State) void {
    rl.unloadSound(state.sound_brick_hit);
    rl.unloadSound(state.sound_player_hit);
    rl.unloadSound(state.sound_ball_lost);
    rl.unloadSound(state.sound_win);
    rl.unloadSound(state.sound_loose);
}

pub fn main() anyerror!void {
    rl.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "zbreakout 0.0.1",
    );
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setExitKey(rl.KeyboardKey.key_q);
    //    rl.toggleBorderlessWindowed();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var state = try State.init(allocator, try initRandom());
    defer state.deinit();

    loadSounds(&state);
    defer unloadSounds(&state);

    gameLoop(&state);
}
