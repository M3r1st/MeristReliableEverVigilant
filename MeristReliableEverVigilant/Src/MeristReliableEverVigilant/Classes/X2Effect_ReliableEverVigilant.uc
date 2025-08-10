class X2Effect_ReliableEverVigilant extends X2Effect_Persistent;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
    local XComGameState_Unit    UnitState;
    local XComGameState_Player  PlayerState;
    local X2EventManager        EventMgr;
    local Object                EffectObj;

    UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));

    if (UnitState != none)
    {
        PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));

        if (PlayerState != none)
        {
            EventMgr = `XEVENTMGR;

            EffectObj = EffectGameState;
        
            EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', ReliableEverVigilant_AbilityListener, ELD_OnStateSubmitted,, UnitState);
            EventMgr.RegisterForEvent(EffectObj, 'PlayerTurnEnded', ReliableEverVigilant_TurnEndListener, ELD_OnStateSubmitted, class'X2Ability_ReliableEverVigilant'.default.EventPriority, PlayerState,, EffectObj);
        }
    }
}

static function EventListenerReturn ReliableEverVigilant_AbilityListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameStateContext_Ability  AbilityContext;
    local XComGameState_Ability         AbilityState;
    local XComGameState_Unit            UnitState;
    local XComGameState                 NewGameState;
    local UnitValue                     UnitValue;

    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

    if (AbilityContext == none || AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt)
        return ELR_NoInterrupt;

    UnitState = XComGameState_Unit(EventSource);
    AbilityState = XComGameState_Ability(EventData);

    if (UnitState == none || AbilityState == none)
        return ELR_NoInterrupt;

    if (class'X2Ability_ReliableEverVigilant'.default.EverVigilantStopOnAbility.Find(AbilityState.GetMyTemplateName()) != INDEX_NONE
        || AbilityState.IsAbilityInputTriggered() && AbilityState.GetMyTemplate().Hostility != eHostility_Movement
        && class'X2Ability_ReliableEverVigilant'.default.EverVigilantIgnore.Find(AbilityState.GetMyTemplateName()) == INDEX_NONE)
    {
        `LOG(AbilityState.GetMyTemplateName() $ " is not a valid ability. Updating Ever Vigilant counter", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
        UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
        UnitState.GetUnitValue(class'X2Ability_ReliableEverVigilant'.default.REVCounterName, UnitValue);
        UnitState.SetUnitFloatValue(class'X2Ability_ReliableEverVigilant'.default.REVCounterName, int(UnitValue.fValue) + 1.0, eCleanup_BeginTurn);
        `TACTICALRULES.SubmitGameState(NewGameState);
    }

    return ELR_NoInterrupt;
}

static function EventListenerReturn ReliableEverVigilant_TurnEndListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameStateHistory          History;
    local XComGameState_Effect          EffectState;
    local XComGameState_Unit            UnitState;
    local UnitValue                     UnitValue;

    local StateObjectReference          OverwatchRef;
    local XComGameState_Ability         OverwatchState;
    local OverwatchAbilityInfo          OverwatchAbilityInfo;
    local array<OverwatchAbilityInfo>   OverwatchAbilitiesSorted;
    local name                          OverwatchAbilityName;
    local bool                          bCanUseOverwatch;
    local X2AbilityCost                 Cost;

    local XComGameState                 NewGameState;
    local EffectAppliedData             ApplyData;
    local X2Effect                      VigilantEffect;
    local name                          ActionPointType;
    local int                           iNumPoints;
    local int                           Index;

    History = `XCOMHISTORY;

    EffectState = XComGameState_Effect(CallbackData);
    if (EffectState != none)
    {
        UnitState = XComGameState_Unit(GameState.GetGameStateForObjectID(EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
        if (UnitState == none)
            UnitState = XComGameState_Unit(History.GetGameStateForObjectID(EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
        if (UnitState != none)
        {
            if (!UnitState.GetUnitValue(class'X2Ability_ReliableEverVigilant'.default.REVCounterName, UnitValue) || UnitValue.fValue == 0)
            {
                if (UnitState.NumAllReserveActionPoints() == 0)
                {
                    `LOG("Can activate Ever Vigilant", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                    foreach class'X2Ability_ReliableEverVigilant'.default.OverwatchAbilities(OverwatchAbilityInfo)
                    {
                        OverwatchAbilitiesSorted.AddItem(OverwatchAbilityInfo);
                    }
                    OverwatchAbilitiesSorted.Sort(SortOverwatchAbilities);

                    foreach OverwatchAbilitiesSorted(OverwatchAbilityInfo)
                    {
                        OverwatchAbilityName = OverwatchAbilityInfo.AbilityName;
                        OverwatchRef = UnitState.FindAbility(OverwatchAbilityName);
                        if (OverwatchRef.ObjectID != 0)
                        {
                            OverwatchState = XComGameState_Ability(History.GetGameStateForObjectID(OverwatchRef.ObjectID));
                            if (OverwatchState != none)
                            {
                                if (OverwatchState.CanActivateAbility(UnitState,, true) == 'AA_Success')
                                {
                                    bCanUseOverwatch = true;
                                    foreach OverwatchState.GetMyTemplate().AbilityCosts(Cost)
                                    {
                                        if (X2AbilityCost_ActionPoints(Cost) == none)
                                        {
                                            if (Cost.CanAfford(OverwatchState, UnitState) != 'AA_Success')
                                            {
                                                `LOG(OverwatchAbilityName $ " is unavailable", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                                                bCanUseOverwatch = false;
                                                break;
                                            }
                                        }
                                    }
                                    if (bCanUseOverwatch)
                                    {
                                        `LOG("Success! " $ OverwatchAbilityName $ " is available", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    if (bCanUseOverwatch)
                    {
                        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
                        UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
                        //  apply the EverVigilantActivated effect directly to the unit
                        ApplyData.EffectRef.LookupType = TELT_AbilityShooterEffects;
                        ApplyData.EffectRef.TemplateEffectLookupArrayIndex = 0;
                        ApplyData.EffectRef.SourceTemplateName = 'EverVigilantTrigger';
                        ApplyData.PlayerStateObjectRef = UnitState.ControllingPlayer;
                        ApplyData.SourceStateObjectRef = UnitState.GetReference();
                        ApplyData.TargetStateObjectRef = UnitState.GetReference();
                        VigilantEffect = class'X2Effect'.static.GetX2Effect(ApplyData.EffectRef);
                        `assert(VigilantEffect != none);
                        VigilantEffect.ApplyEffect(ApplyData, UnitState, NewGameState);

                        if (GetAllowedActionPointType(OverwatchState, UnitState, ActionPointType, iNumPoints))
                        {
                            for (Index = 0; Index < iNumPoints; Index++)
                            {
                                if (OverwatchState.CanActivateAbility(UnitState) != 'AA_Success')
                                {
                                    UnitState.ActionPoints.AddItem(ActionPointType);
                                }
                                else
                                {
                                    break;
                                }
                            }

                            if (Index > 0)
                            {
                                `LOG("Added " $ Index $ " points. Type: " $ ActionPointType, class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                            }
                        }

                        UnitState.SetUnitFloatValue(class'X2Ability_SpecialistAbilitySet'.default.EverVigilantEffectName, 1, eCleanup_BeginTurn);
                            
                        `TACTICALRULES.SubmitGameState(NewGameState);
                        return OverwatchState.AbilityTriggerEventListener_Self(EventData, EventSource, GameState, EventID, CallbackData);
                    }
                    else
                    {
                        `LOG("No overwatch abilities available", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                    }
                }
                else
                {
                    `LOG("Reserve array is not empty", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
                }
            }
            else
            {
                `LOG("Cannot activate Ever Vigilant", class'X2Ability_ReliableEverVigilant'.default.bLog, GetFuncName());
            }
        }
    }

    return ELR_NoInterrupt;
}

static function bool GetAllowedActionPointType(XComGameState_Ability AbilityState, XComGameState_Unit UnitState, out name ActionPointType, out int iNumPoints, optional bool bReserve)
{
    local X2AbilityTemplate                     AbilityTemplate;
    local X2AbilityCost                         AbilityCost;
    local X2AbilityCost_ActionPoints            ActionPointCost;
    local X2AbilityCost_ReserveActionPoints     ReserveActionPointCost;

    AbilityTemplate = AbilityState.GetMyTemplate();

    if (AbilityTemplate.AbilityCosts.Length > 0)
    {
        if (bReserve)
        {
            foreach AbilityTemplate.AbilityCosts(AbilityCost)
            {
                ReserveActionPointCost = X2AbilityCost_ReserveActionPoints(AbilityCost);
                if (ReserveActionPointCost != none)
                {
                    if (ActionPointType == '')
                        ActionPointType = ReserveActionPointCost.AllowedTypes[0];

                    iNumPoints = Max(iNumPoints, ReserveActionPointCost.iNumPoints);
                }
            }
        }
        else
        {
            foreach AbilityTemplate.AbilityCosts(AbilityCost)
            {
                ActionPointCost = X2AbilityCost_ActionPoints(AbilityCost);
                if (ActionPointCost != none)
                {
                    if (ActionPointType == '')
                        ActionPointType = ActionPointCost.AllowedTypes[0];

                    iNumPoints = Max(iNumPoints, ActionPointCost.GetPointCost(AbilityState, UnitState));
                }
            }
        }
    }

    if (ActionPointType != '')
        return true;

    return false;
}

delegate int SortOverwatchAbilities(OverwatchAbilityInfo A, OverwatchAbilityInfo B)
{
    if (A.Priority < B.Priority)
        return -1;
    else if (A.Priority > B.Priority)
        return 1;
    else
        return 0;
}