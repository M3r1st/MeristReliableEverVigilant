class X2DownloadableContentInfo_MeristReliableEverVigilant extends X2DownloadableContentInfo;

static event OnPostTemplatesCreated()
{
    local X2AbilityTemplate Template;

    Template = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('EverVigilant');

    if (Template != none)
    {
        Template.AdditionalAbilities.Removeitem('EverVigilantTrigger');
        Template.AdditionalAbilities.Removeitem('NewEverVigilantTrigger');

        Template.AdditionalAbilities.AddItem(class'X2Ability_ReliableEverVigilant'.default.REVAbilityName);
    }
}