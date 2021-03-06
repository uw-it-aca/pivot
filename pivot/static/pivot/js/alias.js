/* Maps MajorName-Pathway to other acceptable search terms
Ex: If you search CSE, the major corresponding to 'C SCI-0' should
show up in the search results (in this case: Computer Science on the Seattle Campus) */

const search_alias = {
	'ACMS-0-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-10-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-20-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-30-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-40-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-50-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-70-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'ACMS-80-1-5': ['AMATH', 'Applied Math', 'Applied and Computational Mathematical Sciences', 'Applied & Computational Mathematical Sciences'],
	'C-SCI-0-1-5': ['CSE'],
	'C-SCI-10-1-5': ['CSE'],
	'CMP-E-0-1-6': ['CSE'],
	'CIV-E-0-1-6': ['CE'],
	'IND-E-0-1-6': ['IE']
};


/* Maps a major without a page in myplan, to the correct page.
 * Corrects data issues for majors that myplan considers tracts under a parent major. 
 * Ex: Information Systems 'I S' is a Business Major at UW Seattle, although considered
 * a track under business in Myplan, thus the link we create should direct to the parent major major
 * not an error page because the myplan major page does not exist.
 */

// Define constants in case a common link changes
var seattle_business = ['BUS'];
var tacoma_business = ['T BUS'];

const myplan_alias = {
	'I S': seattle_business,
	'ACCTG': seattle_business,
	'ENTRE': seattle_business,
	'B A': seattle_business,
	'FINANC': seattle_business,
	"HRMGT": seattle_business,
	'MKTG': seattle_business,
	'OSCM': seattle_business,
	'B BUSX': ['B BUS'],  // No var above because there's only one exception.
	'T ACCT': tacoma_business,
	'T FIN': tacoma_business,
	'T MGMT': tacoma_business,
	'T MKTG': tacoma_business,
};
