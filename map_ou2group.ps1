$ErrorActionPreference = "Stop"

cd $PSScriptRoot

. .\wec_config.ps1

foreach ( $grp in $GroupList.GetEnumerator() ){
 
    $group = Summon-Group "$($grp.key)"

    $members = @();
    foreach ( $ou in $grp.value ) {
        try {
            $members += , ( Get-ADComputer -Filter * -SearchBase "$ou" )
        }
        catch {
            continue
        }
    }

    If (-Not $members) { continue }

    # Add all mathcing members found in the given OUs
    echo "UPDATING Membership for '$($group.distinguishedName)'"
    $members | Add-ADPrincipalGroupMembership -MemberOf $group

    # Remove any existing member not found in the given OUs
    Foreach ( $mem in (Get-ADGroupMember -Identity $group) ) {
        If (-Not ($members.Where({$_.distinguishedName -eq $mem.distinguishedName}))) {
            echo "REMOVING '$($mem.distinguishedName)' from '$($group.distinguishedName)'"
            Remove-ADGroupMember -Identity $group -Members $mem -Confirm:$false
        }
    }
}
 
