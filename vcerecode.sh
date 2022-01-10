#!/bin/bash
# program : vcerecode.sh
# purpose : ...
# execute : vcerecode.sh pedigree_file data_file
# author  : Freddy Fikse, Interbull Centre
# comments: fields need to be seperated by blanks
#           first 'nr_ped' in data file has to be animal IDs
#           the next 'nr_cat' fields are assumed to contain categorical values,
#               and are recoded
#           the next 'nr_real' fields are not recoded (real values)
#           in the coded data file the first field contains the coded ID, the
#               next 'nr_real' fields contain non recoded real values, and the
#               last 'nr_cat' fields contain recoded categorial values
#           pedigree file needs to be sorted:
#               ancestors before parents before progeny
#               ancestor pedigree record: ID 0 0
#           fourth ID field in coded pedigree file contains genetic group code
# revision history:
#           12 mar 1998: original code
#            2 jul 1998: adapted to use with variable nr. of fields
#           24 apr 2000: give nr. of fields as parameter

# check for input parameters
set -- `getopt p:o:t: $*`
if [ $? -ne 0 ]
then
  echo "usage: ${0##*/}"
  echo "       [-p pedigree file]"
  echo "       [-o data file]"
  echo "       [-t task]"
  echo "       task is a sequence of p's, c's and s's"
  exit 1
fi

for i in $*
do
    case $i in
        -p) ped=$2; shift 2;;
        -o) dat=$2; shift 2;;
        -t) task=$2; shift 2;;
        --) shift; break;;
    esac
done

gawk -v str_task=$task 'BEGIN {
    # nr. of real/categoric/pedigree variables
    fmt_skip="%12s"
    fmt_cat="%7d"
    fmt_ped="%7d"
    obsfile="a"
    pedfile="b"
    #     CHANGE above to own preference

    # how many fields in data file
    getline < "'${dat}'"
    nr_field=NF

    # check whether found is consistent with declared above
    if( nr_field != length(str_task) ) {
       print "Warning: number of fields is not consistent" | "cat 1>&2"
       print "         expected: ", length(str_task), ";  found: ",
              nr_field | "cat 1>&2"
    }

    # parse str_task
    split(str_task,flds,"")
    for( i=1; i<= length(flds); i++ ) {
      switch(substr(str_task,i,1)) {
        case "p":
        case "c":
        case "s":
          break
        default:
          print "Warning: unknow task :: ", substr(str_task,i,1) | "cat 1>&2"
      }
    }

    # loop over all fields except animal ID, start at column nr_ped+1
    # fields with level=0 will also have 1 in the coded file
    for( i=1; i<=nr_field; i++ ) {
        cod[i,0]=1;
    }

    # read pedigree file, (store) recode animal ID, and write coded IDs
    while (getline < "'${ped}'" > 0 ) {
        id[$1] = ++nr
        c=4
        if($2==0 && $3==0) nog++
        else if(id[$2]>nog && id[$3] >nog) c=1
        else if(id[$3]>nog) c=2
        else if(id[$2]>nog) c=3

        printf( "%10d%10d%10d%10d\n", id[$1], id[$2], id[$3], c ) > pedfile
#       printf( "%10d%10d%10d%10d\n", id[$1], id[$2], id[$3], 0 ) > pedfile
#       printf( "%10d%10d%10d%10d\n", id[$1], id[$2], 0, 0 ) > pedfile
        # below to make key file for pedigree:
        print $1, id[$1] > "ped.key"
        # below to add dam to obs.cod
        #d[id[$1]] = id[$3]
    }

    # determine new field number for categorical fields
#   for( i=nr_ped+1; i<=nr_ped+nr_cat; i++ ) {
#       newfld[i]=nr_real+i
#   }
}

{
  if (NF == nr_field) {

    # loop over all fields, do only something for fields with categorical data
    for( i=1; i <= nr_field; i++) {
      if( flds[i] != "c") { continue }
      if( (i,$i) in cod ) {
        $i=cod[i,$i]
      }
      else {
        cod[i,$i]=++nrf[i]
        # below for key file
        #print i, newfld[i], $i, cod[i,$i] > "obs.key"
        $i=cod[i,$i]
      }
    }

    # loop over all pedigree fields and print those
    for( i=1; i<=nr_field; i++) {
      switch(flds[i]) {
        case "p":
          printf( fmt_ped, id[$i] ) > obsfile
          break
        case "c":
          printf( fmt_cat, $i ) > obsfile
          break
        case "s":
          printf( fmt_skip, $i ) > obsfile
          break
        default:
      }
    }

    # print coded dam ID
    #printf( fmt_ped, d[$1] ) > obsfile

    printf( "\n" ) > obsfile
  }
  else {
    print "Warning: incorrect number of fields for record" | "cat 1>&2"
    print $0 | "cat 1>&2"
  }
}

END {

  # print nr. of levels for each categorical effect
  printf("add. genetic %10d\n", nr)
  for(i in nrf) {
    printf("%3d %10d\n", i,nrf[i])
  }

}' ${dat}
