#!/bin/bash 

#This script first sets up ontologizer and downloads the latest .obo and assoication files
#If the user does not know a taxon id this tool includes functionality to search for it
#The user can enter in a taxon id and the script will download the corresponding gene association file from www.geneontology.org 
#If the gene association file cannot be found in geneontology.org this tool creates a GAF for the taxon using QuickGO.
#For this script to function properly subversion (svn) needs to be installed!
#Author: Kent Guerriero

#TO USE:
#Place this script in the file where you want your GAF file to be created
#Run this script on the command line with 'bash ontologizerHelper.bash' 

#Check to see if ontologizer is up to date(using timestamp)
#If not download the latest version of ontologizer from svn
wget -S -N https://svn.code.sf.net/p/ontologizer/svn/trunk/ontologizer.gui/ontologizer.jnlp
#Check if ontologizer downloaded successfully 
if [ $? -ne 0 ]
   then
   echo "There was a problem downloading the ontologizer file from the ontologizer svn
Please check the download location in /etc/atmo/post.scripts.d
The program will now exit"
   exit 1 
fi

#Check to see if .obo file is up to date(using timestamp)
#If not download the latest .obo file
wget -S -N http://www.geneontology.org/ontology/obo_format_1_2/gene_ontology_ext.obo
#Checks if .obo downloaded successfully
if [ $? -ne 0 ];then 
   echo "There was a problem downloading the .obo file
         Check the download link to ensure it is correct, this is located in 
         /etc/atmo/post.scripts.d/"
   exit 1
fi


#Global variable for users taxonid
taxonid=0

#Generic help statment for the script
#This explains what ontologizer does/ needs and what this script does/needs
printHelpStatement(){
   echo "
This tool will download the latest gene association files (.gaf) given a taxon id. 
If the GAF is a multispecies file, this program will filter out the non relevant species.
This tool also updates the GeneOntology file(.obo) and the Ontologizer program (if needed). 

If you are not able to find the taxon ID for a species that you know exists use the tool located at http://www.agbase.msstate.edu/cgi-bin/taxbrowser.cgi

Ontologizer requires 4 input files to run correctly 
(1) GenoOntology (.obo) file 
   We download the latest version for you
(2) The Gene Association file
   This is what we search for when you enter your taxon ID
   If we cannot find this, you will need to provide this to Ontologizer.
(3) The population set 
   You will need to provide this to Ontologizer.
(4) The study set
   You will need to provide this to Ontologizer
" 
}

#This function allows the user to choose from 4 options
#These options are present in the echo statement
programStartInput(){
   echo "
   Enter '1' to search for a gene association file with a taxon ID
   Enter '2' to search for a taxon ID using a species name
   Enter 'exit' to exit the tool
   Enter '--help' to display more information about the tool
   " 
   read generalInput

#If user enters 1 we know they have a taxonid they wish to create a GAF for
   if [ $generalInput == "1" ];then
      searchWithTaxonId
#If user enters 2 they do not know the taxon id for their species and we need to look it up for them
   elif [ $generalInput == "2" ]; then
      lookUpTaxonId
   elif [ $generalInput == "--help" ]; then
      printHelpStatement
      programStartInput 
   elif [ $generalInput == "exit" ]; then
      exit 0; 
   else 
      echo "Invalid input"
      programStartInput
fi
}

#This looks up the taxonid for a given species
#It uses the uniprot database to query for the taxonid
#It is saved in a file(on atmosphere desktop in ontologizer folder) and printed out to the console to the user can see it
lookUpTaxonId(){
   echo "Enter either the common name (eg. chicken) or the scientific name (eg. gallus gallus)"
   read userTaxonName
   wget -q -O ~/Desktop/Ontologizer/taxonSearch.txt "http://www.uniprot.org/taxonomy/?query=$userTaxonName&force=yes&sort=score&limit=10&format=tab"
   cat ~/Desktop/Ontologizer/taxonSearch.txt | sed "s/;/\n/g" | sed "s/\t\t/\n/g" | egrep -i "$userTaxonName" | egrep '.*[0-9].*'
   rm taxonSearch.txt
   programStartInput
}

#This function gets the taxonid from the user 
#It then searches the geneOFileLocations.txt file to see if the file is located at geneOntology.org
searchWithTaxonId(){
   promptForTaxonID
   taxIdLocation=""
   #First we will use user input to look for taxon ID in files at geneOntology.org
   taxIdLocation=$(grep -P "\t$taxonid\t" ~/Desktop/Ontologizer/geneOFileLocations.txt)
   searchForFile
   programStartInput
}

#This function prompts the user for a taxonID
promptForTaxonID(){
echo "Please enter a taxon id (to exit enter 'exit'):"
read taxonid

#If the user entered exit bring them out of the script
if [ $taxonid == "exit" ]; then
   programStartInput  
fi

#The user entered --help
if [ $taxonid == "--help" ]; then
   printHelpStatement
   promptForTaxonID
fi
}

#Creates the GAF file from QuickGo
createFileFromQuickGOSource(){
   echo "File is being created, please wait"
   wget -O ~/Desktop/Ontologizer/gene_association$taxonid.gaf "http://www.ebi.ac.uk/QuickGO/GAnnotation?format=gaf&limit=-1&tax=$taxonid"
   lineCAnnot=$(cat ~/Desktop/Ontologizer/gene_association$taxonid.gaf | wc -l )
   if [ $lineCAnnot -lt 200 ]; then
      echo "POSSIBLE INCORRECT GAF. The file we have created is smaller than expected, please check the file located in ~/Desktop/Ontologizer/gene_association$taxonid.gaf 
The QuickGo website may also be unavailable. 
"
   else
      echo "GAF downloaded. File is stored in ~/Desktop/Ontologizer/gene_association$taxonid.gaf"
      echo "Current number of annotations is $lineCAnnot"
   fi
}

#Creates the GAF from GeneOntology.org
createFileFromGeneOSource(){
   downloadLocation="go/gene-associations/"
   downloadLocation=$downloadLocation""$fileName
   echo "Found file, downloading..."
   cvs -q -d:pserver:anonymous@cvs.geneontology.org:/anoncvs checkout $(echo "$downloadLocation")
#Checks to see if there was a problem downloading the gene association file 
   if [ $? -ne 0 ]; then
      echo "There was a problem downloading the file, you may need to manually download it at cvs.geneontolog.org"
      exit 1
   else
#Unzips and moves the GAF to the directory where the script is
      rm -v $( echo $downloadLocation | sed 's/.gz//g' ) 2> /dev/null > /dev/null
      gunzip -dk $downloadLocation
      cp $( echo $downloadLocation | sed 's/.gz//g' ) . 
      echo "File saved in $( echo $PWD ) "
   fi
}


#This function ensures that the file found from the user given taxon ID is correct. 
#The function then downloads the correct GAF files according to the taxon ID 
#If we cannot locate the taxon id in the files from geneOntology.org we will use QuickGO to create the GAF
searchForFile()
{
   isInfoCorrect='n'
#Checks to see if the file found is the correct file (asks user)
   if [ "$taxIdLocation" != "" ]; then
      echo "FOUND: $taxIdLocation
      Does this look correct? (y/n)"
      read isInfoCorrect
   else  #If we cant find the taxonid in the files at geneontology.org we use QuickGO to generate the GAF
      echo "Taxon id $taxonid NOT FOUND in GAF file from GO.org. We can create a GAF using QuickGO, would you like to do this? (y/n)"
      read createFromQuickGo
      if [ "$createFromQuickGo" = "y" ];then
         createFileFromQuickGOSource     
      fi
   fi
#This downloads a max of two files specified in the geneOFileLocations.txt file (the location of gene associations)
   if [ "$isInfoCorrect" = "y" ]; then   
#First file is searched for
      fileName=$(echo $taxIdLocation | egrep -o ":.*," | tr -d ':'| tr -d ',')
      createFileFromGeneOSource

#This part of the code checks for a second possible GAF
      fileName=$(echo $taxIdLocation | egrep -o ",.*" | tr -d ':'| tr -d ',')  
      if [ "$fileName" != "" ]; then
         createFileFromGeneOSource
      fi
   else
#Found GAF file is not what the user is looking for
#Prompt the user to enter the taxon id again
      promptForTaxonID
      taxIdLocation=""
      taxIdLocation=$(grep -P "\t$taxonid\t" ~/Desktop/Ontologizer/geneOFileLocations.txt)
      searchForFile
   fi
}

#Display welcome message and begin by prompting the user
echo "
Welcome to Ontologizer on iPlant Atmosphere
This script is designed to download and update files assoicated with Ontologizer
"
programStartInput
exit 0
