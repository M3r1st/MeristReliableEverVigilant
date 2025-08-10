class X2Ability_ReliableEverVigilant extends X2Ability config(Game);

struct OverwatchAbilityInfo
{
    var name AbilityName;
    var int Priority;
};

var privatewrite name REVAbilityName;
var privatewrite name REVCounterName;

var config array<name> EverVigilantIgnore;
var config array<name> EverVigilantStopOnAbility;

var config array<OverwatchAbilityInfo> OverwatchAbilities;

var config int EventPriority;

var config bool bLog;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;
    
    Templates.AddItem(EverVigilantTrigger());

    return Templates;
}

static function X2AbilityTemplate EverVigilantTrigger()
{
    local X2AbilityTemplate                 Template;
    local X2Effect_ReliableEverVigilant     Effect;

    `CREATE_X2ABILITY_TEMPLATE(Template, default.REVAbilityName);

    Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_EverVigilant";
    Template.AbilitySourceName = 'eAbilitySource_Perk';
    Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
    Template.Hostility = eHostility_Neutral;
    Template.bIsPassive = true;
    Template.bUniqueSource = true;

    Template.AbilityToHitCalc = default.DeadEye;
    Template.AbilityTargetStyle = default.SelfTarget;
    Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

    Effect = new class'X2Effect_ReliableEverVigilant';
    Effect.BuildPersistentEffect(1, true, false);
    Template.AddTargetEffect(Effect);

    Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

    Template.bCrossClassEligible = false;

    return Template;
}

defaultproperties
{
    REVAbilityName = M31_ReliableEverVigilantTrigger
    REVCounterName = M31_ReliableEverVigilantCounter
}