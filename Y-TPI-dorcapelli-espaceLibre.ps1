<#
.NOTES
    *****************************************************************************
    ETML
    Nom du script:	Y-TPI-dorcapelli-espaceLibre.ps1
    Auteur:	Dorian Capelli
    Date:	11.05.2023
 	*****************************************************************************

.SYNOPSIS
    Récupére les informations des volumes pour calculer leurs pourcentages d'espace libre
 	
.DESCRIPTION
    En faisant du remoting sur les postes voulu, on récupère leurs tailles et leurs espaces libres de leurs volumes pour calculer leurs pourcentage.
    En vérifiant si le poste voulu est éteint, parce que si le poste est éteint, le script ne pourra pas récupérer les informations des volumes.
    Le pourcentage est caluculer comme cela: (espace libre / taille totale) * 100.
  	
.OUTPUTS
    le script crée un fichier log pour chaque machine dans tous les cas possible.
	
.EXAMPLE
	.\Y-TPI-dorcapelli-espaceLibre.ps1
    Transcript started, output file is D:\Log\DisquesSERV2K19-TPI_22-05-2023_14-59-22.log
    Le disque D a 99,59 % d'espace libre.
    Le disque C a 70,1 % d'espace libre.
    Le disque S a 87,16 % d'espace libre.
    Transcript stopped, output file is D:\Log\DisquesSERV2K19-TPI_22-05-2023_14-59-22.log
    Transcript started, output file is D:\Log\DisquesCLIENT-WIN10-1_22-05-2023_14-59-22.log
    Le disque C a 62,38 % d'espace libre.
    Transcript stopped, output file is D:\Log\DisquesCLIENT-WIN10-1_22-05-2023_14-59-22.log
    Transcript started, output file is D:\Log\DisquesCLIENT-WIN10-2_22-05-2023_14-59-22.log
    Le disque C a 60,51 % d'espace libre.
    Transcript stopped, output file is D:\Log\DisquesCLIENT-WIN10-2_22-05-2023_14-59-22.log
#>
#Nom de l'utilisateur avec lequel on se connectera en remoting
$USERNAME = "script"
#Mot de passe de l'utilisateur utilisé pour le remoting
$PASSWORD = ".Etml-44" | ConvertTo-SecureString -AsPlainText -Force
#Création de l'objet credential
$CRED = new-object -typename System.Management.Automation.PSCredential -argumentlist $USERNAME, $PASSWORD
#Chemin où on crée le fichier log
$PATH_LOG = "D:\Log\"
#Partie Fixe du nom du fichier log
$NAME_LOG = "Disques"
#Obtiens la date et l'heure du lancement du script pour l'insérer dans le nom du fichier log
$DATE = Get-Date -Format "dd-MM-yyy_HH-mm-ss"
#Multiplicateur pour obtenir des pourcentages
$CENT = 100
#Nombre de chiffres après la virgule pour les pourcentages
$NB_COMMA = 2

#Vérifie si le chemin ou le fichier log se crée existe sinon le crée
if(!(Test-Path -Path $PATH_LOG)){
    New-Item -Path $PATH_LOG -ItemType "Directory"
}

#Vérifie si le module de l'Active Directory est importé
if(!(Get-Module -ListAvailable -Name ActiveDirectory)){    
    Import-Module ActiveDirectory
}

#Test si l'utilisateur existe dans le domaine
try{
    #Récupère les informations de l'utilisateur
    Get-ADUser -Identity $USERNAME
}
#Si l'utilisateur n'est pas dans le domaine
catch{
    #Nom du fichier log
    $pathLogFile = $PATH_LOG + $NAME_LOG + "Utilisateur" + "_"+ $DATE + ".log"

    #Commencement de l'enregistrement du fichier log
    Start-Transcript -Path $pathLogFile

    #Inscrit dans le fichier log que l'utilisateur n'existe pas
    Write-Host "L'utilisateur" $USERNAME "n'est pas existant."

    #Arrête de l'enregistrement du fichier log
    Stop-Transcript

    #Arrête le script
    EXIT
}

#Obtient les ordinateurs actifs du domaine
$Computers = Get-ADComputer -Filter {Enabled -eq $true}

#Boucle des ordinateurs sur lesquels le script va s'exécuté
Foreach($computer in $Computers){
    #Nom du fichier log
    $pathLogFile = $PATH_LOG + $NAME_LOG + $computer.Name + "_"+ $DATE + ".log"

    #Commencement de l'enregistrement du fichier log
    Start-Transcript -Path $pathLogFile

    #Si l'ordinateur est allumé
    if(Test-Connection $computer.Name -ErrorAction SilentlyContinue){
        
        try{
            #Création de la session en lien avec le PC distant
            $session = New-PSSession -ComputerName $computer.Name -Credential $CRED -ErrorAction SilentlyContinue
        
            #Exécution en remoting dans la session du block de script entrée
            Invoke-Command -Session $session -ScriptBlock{

                #Récupère tous les disques ayant une lettre
                $Disks = Get-WmiObject -Class win32_logicaldisk | Where-Object -Property DriveType -EQ -Value "3"

                #Boucle parcourant tous les disques de la machine
                Foreach($disk in $Disks){
                
                    #Divise l'espace libre du disque par l'espace total du disque
                    $n = $disk.FreeSpace/$disk.Size

                    #Multiplie le résultat de la division par cent pour obtenir des pourcentages
                    $pourcent = $n*$Using:CENT

                    #Arrondie le pourcentage à deux chiffres après la virgule
                    $pourcent = [math]::Round($pourcent,$Using:NB_COMMA)
                
                    #Entre le pourcentage d'espace libre dans le fichier log en précisant le disque
                    Write-Host "Le disque" $disk.DeviceID "a" $pourcent "% d'espace libre"

                }#Fin de la boucle des disques

            }#Fin du Block de script exécuté en remoting

            #Suppression de la session avec le pc distant
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
        catch{
            #Inscrit dans le fichier log que l'ordinateur viens de s'éteindre
            Write-Host "L'ordinateur" $computer.Name "s'est éteint."
        }
    }
    #Si l'ordinateur n'est pas allumé
    else{
        #Inscrit dans le fichier log que l'ordinateur est éteint
        Write-Host "L'ordinateur" $computer.Name "est éteint."
    }
    #Arrête de l'enregistrement du fichier log
    Stop-Transcript
}#Fin de la boucle des ordinateurs de l'AD