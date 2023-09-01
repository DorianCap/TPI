<#
.NOTES
    *****************************************************************************
    ETML
    Nom du script:	Y-TPI-dorcapelli-groupeCommun.ps1
    Auteur:	Dorian Capelli
    Date:	11.05.2023
 	*****************************************************************************

.SYNOPSIS
    Ce script liste les groupes en communs d'une liste d'utilisateurs.
 	
.DESCRIPTION
    Ce script liste les groupes en communs d'une liste d'utilisateurs en format csv.
    Au début, il vérifie si le module Active Directory de PowerShell est disponible. Sinon, il l'installe.
    Ensuite, il vérifie le fichier donné par l'utilisateur.
    S'il n'existe pas s'il n'est pas en csv et s'il est vide, le script crée un fichier log avec un message d'erreur dans chaque cas.
    Puis, il vérifie si les utilisateurs existent. Si les utilisateurs n'existent pas, un fichier log est créé avec un message d'erreur.
    Après, il compare les groupes des utilisateurs. Si tous les utilisateurs sont dans un groupe, le groupe est noté dans le fichier log.
    Enfin, si le script passe toutes les conditions, le script génère un fichier log contenant tout les groupes en commun
  	
.PARAMETER ListeUsers
    C'est le fichier contenant la liste d'utilisateurs.

.OUTPUTS
    le script crée un fichier log dans tout les cas possible.
    le script génère un fichier log avec toutles groupes en communs de la liste d'utilisateurs
	
.EXAMPLE
	.\Y-TPI-dorcapelli-groupeCommun.ps1 -ListeUsers .\ListeUsers.csv
    Transcript started, output file is D:\Log\ListeGroupesListeUsers15-05-2023_14-04-18.log
    Domain Users
    client
    suisse
    Transcript stopped, output file is D:\Log\ListeGroupesListeUsers15-05-2023_14-04-18.log
#>

#Chemin du fichier contenant la liste des utilisateurs afin de comparer leurs groupes
param([Parameter(Mandatory=$True)][string]$UserList)


#Tableau des groupes du premier utilisateur de la liste
$GroupesShareds = $null
#Tableau des groupes en commun
$GroupesCommons = @()
#Chemin où on crée le fichier log
$PATH_LOG = "D:\Log\"
#Partie Fixe du nom du fichier log
$NAME_LOG = "ListeGroupes"
#Obtiens la date et l'heure du lancement du script pour l'insérer dans le nom du fichier log
$DATE = Get-Date -Format "dd-MM-yyy_HH-mm-ss"
#Sort le nom du fichier entrée par l'utilisateur
$nameFile = Split-Path $UserList -leaf
#Enleve le .csv du nom de fichier
$nameFile = $nameFile -replace '.csv',''
#Nom du fichier log
$pathLogFile = $PATH_LOG + $NAME_LOG + $nameFile + "_" + $DATE + ".log"


#Vérifie si le chemin ou le fichier log se crée existe sinon le crée
if(!(Test-Path -Path $PATH_LOG)){
    New-Item -Path $PATH_LOG -ItemType "Directory"
}

#Commencement de l'enregistrement du fichier log
Start-Transcript -Path $pathLogFile

#Vérifie si le module de l'Active Directory est importé
if(!(Get-Module -ListAvailable -Name ActiveDirectory)){    
    Import-Module ActiveDirectory
}


#Vérifie que le fichier contenant la liste d'utilisateurs existe
if(Test-Path $UserList -PathType leaf -ErrorAction SilentlyContinue){

    #Vérifie que le fichier soit en format csv
    if([System.IO.Path]::GetExtension($UserList) -eq ".csv"){

        #Importe la liste d'utilisateurs
        $Users = Import-Csv -Path $UserList -Encoding UTF8

        #Vérifie si le fichier n'est pas vide
        if(!($Users -eq $null)){

            #Récupère l'en-tête du fichier csv
            $CsvHeaders = ($Users | Get-Member -MemberType NoteProperty).Name

            #Boucle parcourant la liste d'utilisateurs devant être supprimé
            foreach($user in $Users){

                #Test si l'utilisateur existe dans le domaine
                try{

                    #Récupère les information de l'utilisateur
                    $userGroupe = Get-ADUser -Identity $user.username

                    #Récupère le nom des groupes dans lesquels est l'utilisateur
                    $Groupes = Get-ADPrincipalGroupMembership $userGroupe.SamAccountName | select name

                    #Vérifie si la liste de groupes par défaut est définie
                    if($GroupesShareds -ne $null){

                        #Boucle des groupes du premier utilisateur de la liste
                        Foreach($groupeShared in $GroupesShareds){

                            #Vérifie si le groupe est dans la liste de groupes de l'utilisateur
                            if($Groupes -match $groupeShared){
                                #Vérifie si le groupe est déjà dans la liste de groupe en commun
                                if(!($GroupesCommons -contains $groupeShared)){
                                    #Rajoute le groupe dans les groupes en communs
                                    $GroupesCommons += $groupeShared
                                }
                            }
                            #Si le groupe n'est pas la liste du groupe de l'utilisateur
                            else{
                                #Renomme le groupe en champ vide pour que le groupe ne soit plus vérifié
                                $groupeShared.name = ""
                            }
                        }#Fin de la boucle parcourant les groupes du premier utilisateur
                    }
                    #Si la liste de groupes par défaut n'est pas définit
                    else{
                        #Définit la liste de groupes par défaut
                        $GroupesShareds = $Groupes
                    }
                }
                #Si l'utilisateur n'est pas dans le domaine
                catch{
                    #Inscrit dans le fichier log que l'utilisateur n'existe pas
                    Write-Host "L'utilisateur" $User.username "n'est pas existant dans le domaine."
                }

            }#Fin de la boucle parcourant les utilisateurs

            #Si le tableau des groupes en commun n'est pas vide
            if(!($GroupesCommons.Count -eq 0)){
                #Entrée dans le fichier log
                Write-Host "Les utilisateurs existant font tous partie des groupes suivants:"
                #Boucle des groupes en communs
                Foreach($groupeCommon in $GroupesCommons){
                    #Insertion dans le fichier log du nom du groupe en commun
                    Write-Host $groupeCommon.name
                }
            }
            #Si le tableau des groupes en commun est vide
            else{
                Write-Host "Les utilisateurs existants ne font partie d'aucun groupe en commun"
            }
        }
        #Si le fichier est vide
        else{
            
            #Inscrit dans le fichier log que le fichier donné est vide
            Write-Host "Le fichier donné est vide." 
        }
    }
    #Si le fichier donné n'est pas en csv
    else{

        #Inscrit dans le fichier log que le fichier donné n'est pas en format csv
        Write-Host "Le fichier donné n'est pas en format csv."
    }
}
#Si le fichier donné n'existe pas
else{

    #Inscrit dans le fichier log que le fichier donné n'existe pas
    Write-Host "Le fichier donné n'existe pas."
}

#Arrête de l'enregistrement du fichier log
Stop-Transcript