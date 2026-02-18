const assets = @import("assets.zig");

// Animation Set Defines

// Ammo Animations

const ANIM_SET_AMMO: usize = 0;
const ANIM_AMMO_BOUNCER1: usize = 25;

// End of AmmoAnimations

// Birdy Animations

const ANIM_SET_BIRDY: usize = 21;
const ANIM_BIRDY_FLY_RT_DN: usize = 0;
const ANIM_BIRDY_FLY_RT: usize = 1;
const ANIM_BIRDY_FLY_RT_UP: usize = 2;
const ANIM_BIRDY_CAGE: usize = 3;
const ANIM_BIRDY_CAGE_BROKEN: usize = 4;
const ANIM_BIRDY_DEATH: usize = 5;
const ANIM_BIRDY_FEATHER_COL1: usize = 6;
const ANIM_BIRDY_FEATHER_COL2: usize = 7;
const ANIM_BIRDY_FEATHER_COL1_2: usize = 8;
const ANIM_BIRDY_FLY: usize = 9;
const ANIM_BIRDY_DEAD: usize = 19;

// End of Birdy Animations

// Jazz Player Animations

const ANIM_SET_JAZZ: usize = 54;
const ANIM_JAZZ_HOVERBOARD: usize = 1;
const ANIM_JAZZ_HOVERBOARD_TURN_AROUND: usize = 2;
const ANIM_JAZZ_ENDING_BUTTSTOMP: usize = 3;
const ANIM_JAZZ_DEAD: usize = 4;
const ANIM_JAZZ_DEATH: usize = 5;
const ANIM_JAZZ_CROUCHING: usize = 6;
const ANIM_JAZZ_EXITING_CROUCH: usize = 9;
const ANIM_JAZZ_VINE_MOVING: usize = 11;
const ANIM_JAZZ_LEVEL_EXIT: usize = 12;
const ANIM_JAZZ_DESC_1: usize = 13;
const ANIM_JAZZ_BUTTSTOMP: usize = 14;
const ANIM_JAZZ_LANDING: usize = 15;
const ANIM_JAZZ_SHOOT: usize = 16;
const ANIM_JAZZ_SHOOT_UP: usize = 17;
const ANIM_JAZZ_DONE_SHOOTING: usize = 18;
const ANIM_JAZZ_VINE_SHOOT_UP: usize = 23;
const ANIM_JAZZ_VINE: usize = 24;
const ANIM_JAZZ_VINE_IDLE: usize = 25;
const ANIM_JAZZ_VINE_SHOOT: usize = 27;
const ANIM_JAZZ_COPTER: usize = 28;
const ANIM_JAZZ_COPTER_SHOOT: usize = 30;
const ANIM_JAZZ_HPOLE: usize = 31;
const ANIM_JAZZ_HURT: usize = 32;
const ANIM_JAZZ_IDLE1: usize = 33;
const ANIM_JAZZ_IDLE2: usize = 34;
const ANIM_JAZZ_IDLE3: usize = 35;
const ANIM_JAZZ_IDLE4: usize = 36;
const ANIM_JAZZ_IDLE5: usize = 37;
const ANIM_JAZZ_DESC_GUN: usize = 39;
const ANIM_JAZZ_DESC: usize = 40;
const ANIM_JAZZ_JUMP: usize = 41;
const ANIM_JAZZ_ASCENDING: usize = 42;
const ANIM_JAZZ_OFF_BALANCE: usize = 43;
const ANIM_JAZZ_LOOK_UP: usize = 47;
const ANIM_JAZZ_DIZZY: usize = 55;
const ANIM_JAZZ_PUSHING: usize = 56;
const ANIM_JAZZ_DESC_SIDE: usize = 61;
const ANIM_JAZZ_JUMP_SIDE: usize = 63;
const ANIM_JAZZ_BALL: usize = 67;
const ANIM_JAZZ_WALKING: usize = 68;
const ANIM_JAZZ_STARTING_TO_RUN: usize = 70;
const ANIM_JAZZ_RUNNING: usize = 71;
const ANIM_JAZZ_SKIDDING: usize = 72;
const ANIM_JAZZ_STARTING_SKID: usize = 73;
const ANIM_JAZZ_ENDING_SKID: usize = 74;
const ANIM_JAZZ_BUTTSTOMP_PENDING: usize = 75;
const ANIM_JAZZ_SUPER_JUMP: usize = 79;
const ANIM_JAZZ_DRUNK: usize = 80;
const ANIM_JAZZ_SWIM_DOWN: usize = 81;
const ANIM_JAZZ_SWIM: usize = 82;
const ANIM_JAZZ_SWIM_TRANSITION_DOWN: usize = 83;
const ANIM_JAZZ_SWIM_TRANSITION_UP: usize = 84;
const ANIM_JAZZ_SWIM_UP: usize = 85;
const ANIM_JAZZ_SWINGING: usize = 86;
const ANIM_JAZZ_VPOLE: usize = 92;

// End of Jazz Player Animations

// Spaz Player Animations

const ANIM_SET_SPAZ: usize = 85;

// End of Spaz Player Animations

// Item Animations

const ANIM_SET_ITEMS: usize = 67;
const ANIM_1UP: usize = 0;
const ANIM_APPLE: usize = 1;
const ANIM_BANANA: usize = 2;
const ANIM_BARREL: usize = 3;
const ANIM_CRATE: usize = 5;
const ANIM_FLAME_UPGRADE: usize = 10;
const ANIM_CAKE: usize = 11;
const ANIM_BURGER: usize = 12;
const ANIM_CANDY: usize = 13;
const ANIM_CHECKPOINT: usize = 14;
const ANIM_CHEESE: usize = 15;
const ANIM_CHERRY: usize = 16;
const ANIM_CHICKEN: usize = 17;
const ANIM_CHIPS: usize = 18;
const ANIM_CHOCOLATE: usize = 19;
const ANIM_COKE: usize = 20;
const ANIM_CARROT: usize = 21;
const ANIM_GEM: usize = 22;
const ANIM_PICKLE: usize = 23;
const ANIM_CUPCAKE: usize = 24;
const ANIM_DONUT: usize = 25;
const ANIM_EGGPLANT: usize = 26;
const ANIM_UNKNOWN_1: usize = 27;
const ANIM_EXIT: usize = 28;
const ANIM_GUN: usize = 29;
const ANIM_GUN2: usize = 30;
const ANIM_FLAME_UPGRADE_2: usize = 31;
const ANIM_FRIES: usize = 32;
const ANIM_SUPER_SHOES_POWERUP: usize = 33;
const ANIM_HOVERBOARD: usize = 36;
const ANIM_GOLD_COIN: usize = 37;
const ANIM_GRAPES: usize = 38;
const ANIM_HAM: usize = 39;
const ANIM_FLYING_CARROT: usize = 40;
const ANIM_HEART: usize = 41;
const ANIM_HOURGLASS: usize = 42;
const ANIM_ICE_CREAM: usize = 43;
const ANIM_PEAR: usize = 48;
const ANIM_LETTUCE: usize = 49;
const ANIM_PEAR_2: usize = 50;
const ANIM_LIGHTNING_POWERUP: usize = 51;
const ANIM_CRATE_2: usize = 52;
const ANIM_MILK: usize = 53;
const ANIM_BOUNCE_AMMO_CRATE: usize = 54;
const ANIM_ICE_AMMO_CRATE: usize = 55;
const ANIM_ROCKET_AMMO_CRATE: usize = 56;
const ANIM_ROCKET2_AMMO_CRATE: usize = 57;
const ANIM_FLAME_AMMO_CRATE: usize = 58;
const ANIM_TNT_AMMO_CRATE: usize = 59;
const ANIM_GUN_UPGRADE: usize = 60;
const ANIM_BOUNCE_AMMO_UPGRADE: usize = 61;
const ANIM_ICE_AMMO_UPGRADE: usize = 62;
const ANIM_ROCKET_AMMO_UPGRADE: usize = 63;
const ANIM_ROCKET2_AMMO_UPGRADE: usize = 64;
const ANIM_JAZZSPAZ: usize = 70;
const ANIM_TOMATO: usize = 71;
const ANIM_CARROT_2: usize = 72;
const ANIM_PEACH: usize = 73;
const ANIM_PEAR_3: usize = 74;
const ANIM_JAZZ_SODA: usize = 75;
const ANIM_PIE: usize = 76;
const ANIM_PIZZA: usize = 77;
const ANIM_POTION: usize = 78;
const ANIM_PRETZEL: usize = 79;
const ANIM_SANDWICH: usize = 80;
const ANIM_STRAWBERRY: usize = 81;
const ANIM_CARROT_FLOP: usize = 82;
const ANIM_SPAZ_BLASTER_POWERUP: usize = 83;
const ANIM_SILVER_COIN: usize = 84;
const ANIM_UNKNOWN_2: usize = 85;
const ANIM_SPARKLE: usize = 86;
const ANIM_CLOCK: usize = 87;
const ANIM_TACO: usize = 88;
const ANIM_MEATBALL: usize = 89;
const ANIM_BOMB: usize = 90;
const ANIM_HOTDOG: usize = 91;
const ANIM_WATERMELON: usize = 92;
const ANIM_WOODEN_SHARD_1: usize = 93;
const ANIM_WOODEN_SHARD_2: usize = 94;

// End of Item Animations

// Game Setup Menu Animations

const ANIM_SET_GAME_SETUP_MENU: usize = 60;

// End of Game Setup Menu Animations

// Head Animations

const ANIM_SET_HEADS: usize = 38;
const ANIM_HEAD_JAZZ: usize = 3;
const ANIM_HEAD_SPAZ: usize = 4;

// End of Head Animations

// Menu Animations

const ANIM_SET_MENU: usize = 61;
const FONT_OFFSET: usize = -32;
const ANIM_SPRITEFONT_LARGE: usize = 0;
const ANIM_SPRITEFONT_SMALL: usize = 1;

const ANIM_TITLE_BIG: usize = 2;
const ANIM_TITLE_SMALL: usize = 3;

// End of Menu Animations

// Spring Animations

const ANIM_SET_SPRINGS: usize = 92;
const ANIM_SPRING_UP_BLUE: usize = 0;
const ANIM_SPRING_RT_BLUE: usize = 1;
const ANIM_SPRING_DN_BLUE: usize = 2;
const ANIM_SPRING_DN_GREEN: usize = 3;
const ANIM_SPRING_DN_RED: usize = 4;
const ANIM_SPRING_UP_GREEN: usize = 5;
const ANIM_SPRING_RT_GREEN: usize = 6;
const ANIM_SPRING_UP_RED: usize = 7;
const ANIM_SPRING_RT_RED: usize = 8;

// End of Spring Animations

// NPCs

// Bonus

// Each of these only have 1 animation, so just one define for the animation should be sufficient
const ANIM_BONUS: usize = 0;
const ANIM_BONUS_VACANT: usize = 1;

const ANIM_SET_BONUS_VACANT: usize = 11;
const ANIM_SET_BONUS_10: usize = 103;
const ANIM_SET_BONUS_100: usize = 104;
const ANIM_SET_BONUS_20: usize = 105;
const ANIM_SET_BONUS_50: usize = 106;

// End of Bonus

// End of NPCs

// Enemies

// Witch

const ANIM_SET_WITCH: usize = 108;
const ANIM_WITCH_CAST: usize = 0;
const ANIM_WITCH_DEATH: usize = 1;
const ANIM_WITCH_FLY: usize = 2;
const ANIM_WITCH_SPELL: usize = 3;

// End of Witch

// Normal Turtle

const ANIM_SET_NORM_TURTLE: usize = 99;
const ANIM_NORM_TURT_BITE: usize = 0;
const ANIM_NORM_TURT_CHEW: usize = 1;
const ANIM_NORM_TURT_START_REVERSE: usize = 2;
const ANIM_NORM_TURT_END_REVERSE: usize = 3;
const ANIM_NORM_TURT_DEAD: usize = 4;
const ANIM_NORM_TURT_WALK: usize = 7;

// zig fmt: off
pub const EventId = enum(u8) {
    None = 0,
    OneWay = 1,
    Hurt = 2,
    Vine = 3,
    Hook = 4,
    Slide = 5,
    HPole = 6,
    VPole = 7,
    AreaFlyOff = 8,
    Ricochet = 9,
    BeltRight = 10,
    BeltLeft = 11,
    AccBeltR = 12,
    AccBeltL = 13,
    StopEnemy = 14,
    WindLeft = 15,
    WindRight = 16,
    AreaEndOfLevel = 17,
    AreaWarpEOL = 18,
    AreaRevertMorph = 19,
    AreaFloatUp = 20,
    TriggerRock = 21,
    DimLight = 22,
    SetLight = 23,
    LimitXScroll = 24,
    ResetLight = 25,
    AreaWarpSecret = 26,
    Echo = 27,
    ActivateBoss = 28,
    JazzLevelStart = 29,
    SpazLevelStart = 30,
    MultiplayerLevelStart = 31,
    FreezerAmmoPlus3 = 33,
    BouncerAmmoPlus3 = 34,
    SeekerAmmoPlus3 = 35,
    ThreeWayAmmoPlus3 = 36,
    ToasterAmmoPlus3 = 37,
    TNTAmmoPlus3 = 38,
    Gun8AmmoPlus3 = 39,
    Gun9AmmoPlus3 = 40,
    StillTurtleshell = 41,
    SwingingVine = 42,
    Bomb = 43,
    SilverCoin = 44,
    GoldCoin = 45,
    Guncrate = 46,
    Carrotcrate = 47,
    OneUpcrate = 48,
    Gembarrel = 49,
    Carrotbarrel = 50,
    OneUpBarrel = 51,
    BombCrate = 52,
    FreezerAmmoPlus15 = 53,
    BouncerAmmoPlus15 = 54,
    SeekerAmmoPlus15 = 55,
    ThreeWayAmmoPlus15 = 56,
    ToasterAmmoPlus15 = 57,
    TNT = 58,
    Airboard = 59,
    FrozenGreenSpring = 60,
    GunFastFire = 61,
    SpringCrate = 62,
    RedGemPlus1 = 63,
    GreenGemPlus1 = 64,
    BlueGemPlus1 = 65,
    PurpleGemPlus1 = 66,
    SuperRedGem = 67,
    Birdy = 68,
    GunBarrel = 69,
    GemCrate = 70,
    JazzSpaz = 71,
    CarrotEnergyPlus1 = 72,
    FullEnergy = 73,
    FireShield = 74,
    WaterShield = 75,
    LightningShield = 76,
    MaxWeapon = 77,
    Autofire = 78,
    FastFeet = 79,
    ExtraLive = 80,
    EndofLevelsignpost = 81,
    Sparkle = 82,
    Savepointsignpost = 83,
    BonusLevelsignpost = 84,
    RedSpring = 85,
    GreenSpring = 86,
    BlueSpring = 87,
    Invincibility = 88,
    ExtraTime = 89,
    FreezeEnemies = 90,
    HorRedSpring = 91,
    HorGreenSpring = 92,
    HorBlueSpring = 93,
    MorphIntoBird = 94,
    SceneryTriggerCrate = 95,
    Flycarrot = 96,
    RectGemRed = 97,
    RectGemGreen = 98,
    RectGemBlue = 99,
    TufTurt = 100,
    TufBoss = 101,
    LabRat = 102,
    Dragon = 103,
    Lizard = 104,
    Bee = 105,
    Rapier = 106,
    Sparks = 107,
    Bat = 108,
    Sucker = 109,
    Caterpillar = 110,
    Cheshire1 = 111,
    Cheshire2 = 112,
    Hatter = 113,
    BilsyBoss = 114,
    Skeleton = 115,
    DoggyDogg = 116,
    NormTurtle = 117,
    Helmut = 118,
    Leaf = 119,
    Demon = 120,
    Fire = 121,
    Lava = 122,
    DragonFly = 123,
    Monkey = 124,
    FatChick = 125,
    Fencer = 126,
    Fish = 127,
    Moth = 128,
    Steam = 129,
    RotatingRock = 130,
    BlasterPowerUp = 131,
    BouncyPowerUp = 132,
    IcegunPowerUp = 133,
    SeekPowerUp = 134,
    RFPowerUp = 135,
    ToasterPowerUP = 136,
    PINLeftPaddle = 137,
    PINRightPaddle = 138,
    PIN500Bump = 139,
    PINCarrotBump = 140,
    Apple = 141,
    Banana = 142,
    Cherry = 143,
    Orange = 144,
    Pear = 145,
    Pretzel = 146,
    Strawberry = 147,
    SteadyLight = 148,
    PulzeLight = 149,
    FlickerLight = 150,
    QueenBoss = 151,
    FloatingSucker = 152,
    Bridge = 153,
    Lemon = 154,
    Lime = 155,
    Thing = 156,
    Watermelon = 157,
    Peach = 158,
    Grapes = 159,
    Lettuce = 160,
    Eggplant = 161,
    Cucumb = 162,
    SoftDrink = 163,
    SodaPop = 164,
    Milk = 165,
    Pie = 166,
    Cake = 167,
    Donut = 168,
    Cupcake = 169,
    Chips = 170,
    Candy = 171,
    Chocbar = 172,
    Icecream = 173,
    Burger = 174,
    Pizza = 175,
    Fries = 176,
    ChickenLeg = 177,
    Sandwich = 178,
    Taco = 179,
    Weenie = 180,
    Ham = 181,
    Cheese = 182,
    FloatLizard = 183,
    StandMonkey = 184,
    DestructScenery = 185,
    DestructSceneryBOMB = 186,
    CollapsingScenery = 187,
    ButtStompScenery = 188,
    InvisibleGemStomp = 189,
    Raven = 190,
    TubeTurtle = 191,
    GemRing = 192,
    SmallTree = 193,
    AmbientSound = 194,
    Uterus = 195,
    Crab = 196,
    Witch = 197,
    RocketTurtle = 198,
    Bubba = 199,
    Devildevanboss = 200,
    Devan = 201,
    Robot = 202,
    Carrotuspole = 203,
    Psychpole = 204,
    Diamonduspole = 205,
    SuckerTube = 206,
    Text = 207,
    WaterLevel = 208,
    FruitPlatform = 209,
    BollPlatform = 210,
    GrassPlatform = 211,
    PinkPlatform = 212,
    SonicPlatform = 213,
    SpikePlatform = 214,
    SpikeBoll = 215,
    Generator = 216,
    Eva = 217,
    Bubbler = 218,
    TNTPowerup = 219,
    Gun8Powerup = 220,
    Gun9Powerup = 221,
    MorphFrog = 222,
    ThreeDSpikeBoll = 223,
    Springcord = 224,
    Bees = 225,
    Copter = 226,
    LaserShield = 227,
    Stopwatch = 228,
    JunglePole = 229,
    Warp = 230,
    BigRock = 231,
    BigBox = 232,
    WaterBlock = 233,
    TriggerScenery = 234,
    BollyBoss = 235,
    Butterfly = 236,
    BeeBoy = 237,
    Snow = 238,
    WarpTarget = 240,
    TweedleBoss = 241,
    AreaId = 242,
    CTFBasePlusFlag = 244,
    NoFireZone = 245
};
// zig fmt: on

pub fn event2animsetinxd(id: EventId) ?assets.AnimsetIndex {
    const ammo: usize = ANIM_SET_AMMO;
    const items: usize = ANIM_SET_ITEMS;
    const springs = ANIM_SET_SPRINGS;
    const birdy = ANIM_SET_BIRDY;
    switch (id) {
        .None => return null,
        .Apple => return .{ .animblock = items, .anim = ANIM_APPLE },
        // anim = items->GetAnim(ANIM_APPLE);
        // break;
        .Milk => return .{ .animblock = items, .anim = ANIM_MILK },
        // anim = items->GetAnim(ANIM_MILK);
        // break;
        .Pear => return .{ .animblock = items, .anim = ANIM_PEAR },
        // anim = items->GetAnim(ANIM_PEAR);
        // break;
        .CarrotEnergyPlus1 => return .{ .animblock = items, .anim = ANIM_CARROT },
        // anim = items->GetAnim(ANIM_CARROT);
        // break;
        .GoldCoin => return .{ .animblock = items, .anim = ANIM_GOLD_COIN },
        // = items->GetAnim(ANIM_GOLD_COIN);
        // SpeedModifier = -2.0f;
        // break;
        .SilverCoin => return .{ .animblock = items, .anim = ANIM_SILVER_COIN },
        // anim = items->GetAnim(ANIM_SILVER_COIN);
        // SpeedModifier = -2.0f;
        // break;
        .Cake => return .{ .animblock = items, .anim = ANIM_CAKE },
        // anim = items->GetAnim(ANIM_CAKE);
        // break;
        .Cupcake => return .{ .animblock = items, .anim = ANIM_CUPCAKE },
        // anim = items->GetAnim(ANIM_CUPCAKE);
        // break;
        .Candy => return .{ .animblock = items, .anim = ANIM_CANDY },
        // anim = items->GetAnim(ANIM_CANDY);
        // break;
        .Chocbar => return .{ .animblock = items, .anim = ANIM_CHOCOLATE },
        // anim = items->GetAnim(ANIM_CHOCOLATE);
        // break;
        .ChickenLeg => return .{ .animblock = items, .anim = ANIM_CHICKEN },
        // anim = items->GetAnim(ANIM_CHICKEN);
        // break;
        .RedGemPlus1, .PurpleGemPlus1, .BlueGemPlus1, .GreenGemPlus1 => return .{ .animblock = items, .anim = ANIM_GEM },
        // anim = items->GetAnim(ANIM_GEM);
        // SpeedModifier = 2.0f;
        // break;
        .Donut => return .{ .animblock = items, .anim = ANIM_DONUT },
        // anim = items->GetAnim(ANIM_DONUT);
        // break;
        .GemCrate => return .{ .animblock = items, .anim = ANIM_CRATE },
        // anim = items->GetAnim(ANIM_CRATE);
        // DoesNotFloat = true;
        // state = Still;
        // break;
        .ExtraLive => return .{ .animblock = items, .anim = ANIM_1UP },
        // anim = items->GetAnim(ANIM_1UP);
        // break;
        .Lettuce => return .{ .animblock = items, .anim = ANIM_LETTUCE },
        // anim = items->GetAnim(ANIM_LETTUCE);
        // break;
        .Watermelon => return .{ .animblock = items, .anim = ANIM_WATERMELON },
        // anim = items->GetAnim(ANIM_WATERMELON);
        // break;
        .Peach => return .{ .animblock = items, .anim = ANIM_PEACH },
        // anim = items->GetAnim(ANIM_PEACH);
        // break;
        .Sparkle => return .{ .animblock = items, .anim = ANIM_SPARKLE },
        // anim = items->GetAnim(ANIM_SPARKLE);
        // this->TTL = anim->GetFrameCount() / (float)anim->GetFrameRate();
        // DoesNotFloat = true;
        // break;
        // TODO: Flipped anims
        .RedSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_UP_RED },
        // anim = springs->GetAnim(isFlipped ? ANIM_SPRING_DN_RED : ANIM_SPRING_UP_RED);
        // isFlipped = level->IsWalkable(tileXCoord, tileYCoord + 1, tileset);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // break;
        .GreenSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_UP_GREEN },
        // anim = springs->GetAnim(isFlipped ? ANIM_SPRING_DN_GREEN : ANIM_SPRING_UP_GREEN);
        // isFlipped = level->IsWalkable(tileXCoord, tileYCoord + 1, tileset);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // break;
        .BlueSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_UP_BLUE },
        // anim = springs->GetAnim(isFlipped ? ANIM_SPRING_DN_BLUE : ANIM_SPRING_UP_BLUE);
        // isFlipped = level->IsWalkable(tileXCoord, tileYCoord + 1, tileset);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // break;
        .HorRedSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_RT_RED },
        // anim = springs->GetAnim(ANIM_SPRING_RT_RED);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // isFlipped = level->IsWalkable(tileXCoord - 1, tileYCoord, tileset);
        // break;
        .HorGreenSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_RT_GREEN },
        // anim = springs->GetAnim(ANIM_SPRING_RT_GREEN);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // isFlipped = level->IsWalkable(tileXCoord - 1, tileYCoord, tileset);
        // break;
        .HorBlueSpring => return .{ .animblock = springs, .anim = ANIM_SPRING_RT_BLUE },
        // anim = springs->GetAnim(ANIM_SPRING_RT_BLUE);
        // DoesNotFloat = true;
        // animateOnCollision = true;
        // state = Still;
        // isFlipped = level->IsWalkable(tileXCoord - 1, tileYCoord, tileset);
        // break;
        .BouncerAmmoPlus3 => return .{ .animblock = ammo, .anim = ANIM_AMMO_BOUNCER1 },
        // anim = ammo->GetAnim(ANIM_AMMO_BOUNCER1);
        // ammoType = Bouncer;
        // ammoAdd = 3;
        // break;
        .BouncerAmmoPlus15 => return .{ .animblock = items, .anim = ANIM_BOUNCE_AMMO_CRATE },
        // anim = items->GetAnim(ANIM_BOUNCE_AMMO_CRATE);
        // DoesNotFloat = true;
        // state = Still;
        // break;
        .Savepointsignpost => return .{ .animblock = items, .anim = ANIM_CHECKPOINT },
        // anim = items->GetAnim(ANIM_CHECKPOINT);
        // DoesNotFloat = true;
        // state = Still;
        // animateOnce = true;
        // animateOnCollision = true;
        // stopAtAnimationEnd = true;
        // break;
        .Birdy => return .{ .animblock = birdy, .anim = ANIM_BIRDY_CAGE },
        // anim = birdy->GetAnim(ANIM_BIRDY_CAGE);
        // DoesNotFloat = true;
        else => {},
    }
    return null;
}
