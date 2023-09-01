<#
.NOTES
    *****************************************************************************
    ETML
    Nom du script:	Y-TPI-dorcapelli-suppression.ps1
    Auteur:	Dorian Capelli
    Date:	11.05.2023
 	*****************************************************************************

.SYNOPSIS
    Ce script supprime une liste d'utilisateurs avec leurs homes directory.
 	
.DESCRIPTION
    Ce script supprime une liste d'utilisateurs donnée en format csv avec leurs homes directory.
    Pour le faire, il vérifie s'il est lancé en administrateur en premier lieu.
    Si l'utilisateur ne lance pas correctement, un fichier log est créé avec un message d'erreur.
    Après, il vérifie si le module Active Directory de PowerShell est disponible. Sinon, il l'installe.
    Ensuite, il vérifie le fichier donné par l'utilisateur.
    S'il n'existe pas s'il n'est pas en csv et s'il est vide, le script crée un fichier log avec un message d'erreur dans chaque cas.
    Puis, il vérifie si les utilisateurs existent et qu'ils sont désactivés.
    Si les utilisateurs ne sont pas désactivés ou n'existent pas, un fichier log est créé avec un message d'erreur.
    Enfin, si le script passe tout les conditions, l'utilisateur et son home directory sont supprimé.
  	
.PARAMETER ListeUsers
    C'est le fichier contenant la liste d'utilisateurs à supprimer.

.OUTPUTS
    le script crée un fichier log dans tout les cas possible.
    Le script supprime les utilisateurs demandés qui sont désactivé avec leurs homes directory.
	
.EXAMPLE
	.\Y-TPI-dorcapelli-suppression.ps1 -ListeUsers .\ListeUsers.csv
        Transcript started, output file is D:\Loge\SuppressionListeUsers12-05-2023_09-09-14.log
        L'utilisateur test n'est pas existant.
        L'utilisateur cli1 n'est pas désactivé.
        L'utilisateur cli2 n'est pas désactivé.
        L'utilisateur pablo n'est pas existant.
        Transcript stopped, output file is D:\Loge\SuppressionListeUsers12-05-2023_09-09-14.log
#>

#Chemin du fichier contenant la liste des utilisateurs à supprimé
param([Parameter(Mandatory=$True)][string]$UserList)

#Chemin où on crée le fichier log
$PATH_LOG = "D:\Log\"
#Chemin home directory
$PATH_HOME_DIRECTORY = "D:\HomeDirectory\"
#Partie Fixe du nom du fichier log
$NAME_LOG = "Suppression"
#Obtiens la date et l'heure du lancement du script pour l'insérer dans le nom du fichier log
$DATE = Get-Date -Format "dd-MM-yyy_HH-mm-ss"
#Sort le nom du fichier entrée par l'utilisateur
$nameFile = Split-Path $UserList -leaf
#Enlève le .csv du nom de fichier
$nameFile = $nameFile -replace '.csv',''
#Nom du fichier log
$pathLogFile = $PATH_LOG + $NAME_LOG + $nameFile + "_" + $DATE + ".log"


#Fonction qui test si le script est lancé en administrateur
function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
        return $principal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )
    } catch {
        #Message d'erreur apparaissant dans le fichier log
        Write-Host "Le script n'est pas lancé en mode administrateur. Veuillez le lancer en administrateur."
    }
}

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

#Vérifie si le script est lancé en administrateur
if(Test-IsAdmin){

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

                        #Récupère les informations de l'utilisateur
                        $deleteUser = Get-ADUser -Identity $user.username

                        #Vérifie si l'utilisateur est désactivé
                        if(!($deleteUser.Enabled)){

                            #Supprime l'utilisateur dans l'AD
                            Remove-ADUser -Identity $deleteUser.SamAccountName

                            #Crée le chemin du home directory de l'utilisateur
                            $pathHomeDirectory = $PATH_HOME_DIRECTORY + $deleteUser.SamAccountName

                            #Supprime le home directory de l'utilisateur
                            Remove-Item -Path $pathHomeDirectory

                            #Inscrit dans le fichier log que l'utilisateur a bien été supprimé
                            Write-Host "L'utilisateur" $User.username "est supprimé correctement."

                        }
                        #Si l'utilisateur n'est pas désactivé
                        else{

                            #Inscrit dans le fichier log que l'utilisateur est actif
                            Write-Host "L'utilisateur" $User.username "n'est pas désactivé."
                        }
                    }
                    #Si l'utilisateur n'est pas dans le domaine
                    catch{

                        #Inscrit dans le fichier log que l'utilisateur n'existe pas
                        Write-Host "L'utilisateur" $User.username "n'est pas existant."
                    }

                }#Fin de la boucle foreach
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
}#Fin si l'utilisateur est administrateur

#Arrête de l'enregistrement du fichier log
Stop-Transcript