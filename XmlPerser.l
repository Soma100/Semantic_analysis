NameStartChar	[A-Z]|"_"|[a-z]
NameChar	{NameStartChar}|"-"|"."|[0-9]
WhiteSpace	[ \t\n]

TagORAttrName	({NameStartChar}({NameChar}*))

TagVal		([^<>&]*)
AttrValueDblQut		((["])([^<&"]*)(["]))
AttrValueSinglQut	((['])([^<&']*)([']))

AttribDblQut		(({WhiteSpace}+)({TagORAttrName})({WhiteSpace}*)("=")({WhiteSpace}*)({AttrValueDblQut}))
AttribSinglQut		(({WhiteSpace}+)({TagORAttrName})({WhiteSpace}*)("=")({WhiteSpace}*)({AttrValueSinglQut}))

opentag		([<])({TagORAttrName})({WhiteSpace}*)([>])
opentagWITHclosetag	("<")({TagORAttrName})({WhiteSpace}*)("/>")
opentagWITHattr         ("<")({TagORAttrName})(({AttribDblQut}|{AttribSinglQut})+)({WhiteSpace}*)(">")
opentagWITHclosetagWITHattr   ("<")({TagORAttrName})(({AttribDblQut}|{AttribSinglQut})+)({WhiteSpace}*)("/>")
closetag	("</"){TagORAttrName}({WhiteSpace}*)(">")

%{
#include <stdio.h>
#include <string.h>

#define MAX_NODE_NESTING 1024
#define MAX_NAME_LEN 128
#define MAX_VAL_LEN 256
#define NO_ERROR 0
#define GEN_ERROR 1
#define DUP_ATTR_NAME_ERR 2
#define NODE_NESTING_ERR 3
#define MORE_THAN_ONE_TOP_NODE 4

typedef struct _Attribute {
    char attribName[MAX_NAME_LEN];
    char attribValue[MAX_VAL_LEN];
    struct _Attribute* nextAttrib;
}Attribute; 

typedef struct _Node{
    char tagName[MAX_NAME_LEN]; 
    char tagValue[MAX_VAL_LEN];
    Attribute* attribList;
    struct _Node* childFirst;
    struct _Node* sameLavelSibling;
    struct _Node* motherNode;
}Node;

char *errorFlagPrevContext=NULL;
int gblErrorFlag = NO_ERROR;
int stackTop =0;
Node *topNode = NULL;
Node *prevCloseTag = NULL;
Node* nodeStack[MAX_NODE_NESTING];

void openTagFunc();
void openTagWidCloseTagFunc();
void openTagWidAttrFunc();
void openTagWidCloseTagWidAttrFunc();
void closeTagFunc();
void errorFunc();
void tagValueFunc();
char* parseTagname(char*,Node*);
void parseTagValue(char*,Node*);
int parseAllAttr(char*,Node*);
char* parseEachAttrNameVal(char*,Node*);
void initNode(Node*);
void showParsedXml();
void freeNodes(Node *nd);
%}

%%
{opentag}	openTagFunc();
{opentagWITHclosetag}	openTagWidCloseTagFunc();
{opentagWITHattr}	openTagWidAttrFunc();
{opentagWITHclosetagWITHattr}	openTagWidCloseTagWidAttrFunc();
{closetag}	closeTagFunc();
{TagVal}        tagValueFunc();
.	errorFunc();
%%

char* parseEachAttrNameVal(char* text, Node* nd)
{
		char delim;
		int idx=0,consecutive_whitechar;
		Attribute* tempAttrList;
		Attribute* tempAttrList_Prev;
		char temp_attr_name[MAX_NAME_LEN];
		char temp_attr_val[MAX_NAME_LEN];
		char *valueStartPos;
		Attribute* newAttr;
		
		memset(temp_attr_name,0,MAX_NAME_LEN);
		memset(temp_attr_val,0,MAX_NAME_LEN);

		while(1)//collect the attr name
		{
			if( (*text=='\n') || (*text=='\t') || (*text==' ') || (*text=='='))
				break;
			else
			{
				temp_attr_name[idx] = text[0];
				idx++;
				text++;
			}
		}
		tempAttrList = nd->attribList;
		tempAttrList_Prev = nd->attribList;

		while(tempAttrList != NULL) //check for duplicate attrname in same tag
		{
			if( !strcmp(tempAttrList->attribName,temp_attr_name) )
			{
				errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
				strcpy(errorFlagPrevContext, "Duplicate Attr Name:");
				strcat(errorFlagPrevContext,  temp_attr_name);
				strcat(errorFlagPrevContext,  ":");
				strcat(errorFlagPrevContext,  text);
				return NULL;
			}
			tempAttrList_Prev = tempAttrList;
			tempAttrList = tempAttrList->nextAttrib;
		}
		
		//get value because no duplicate attr name found.
		valueStartPos = strchr(text,'=');
		valueStartPos++;
		text = valueStartPos; //now we have to eat up white space after = if any till " or '
		while(1)
		{
			if( (*text=='"') || 
				(*text=='\'') )
			{
				delim = (*text);
				break;
			}
			if( (*text=='\n') || (*text=='\t') || (*text==' ') ) //eat up white space between = and 1st " or '
			{
				text++;
				continue;
			}
		}
		idx=0;
		consecutive_whitechar = 0;
		text++;
		while(1)
		{
			if( *text==delim)
			{
				break;
			}
			if( (*text=='\n') || (*text=='\t') || (*text==' ') ) 
			{
				if(consecutive_whitechar==0)
				{
					temp_attr_val[idx] = ' ';
					idx++;
					text++;
					consecutive_whitechar=1;
				}
				else
				{
					text++;
					continue;
				}
			}
			else
			{
				temp_attr_val[idx] = text[0];
				idx++;
				text++;
				consecutive_whitechar=0;
			}
		}
		newAttr = (Attribute*)malloc(sizeof(Attribute));
		strcpy(newAttr->attribName, temp_attr_name);
		strcpy(newAttr->attribValue, temp_attr_val);
		newAttr->nextAttrib = NULL;
		printf("%s = '%s'\n",newAttr->attribName,newAttr->attribValue);

		if(tempAttrList_Prev==NULL)
		{
			nd->attribList = newAttr;
		}
		else
		{
			tempAttrList_Prev->nextAttrib =  newAttr;
			//nd->attribList->nextAttrib =  newAttr;
		}
		text++;
		return text;
}

int parseAllAttr(char* text, Node* nd)
{
	int err = NO_ERROR;
//	char *remainingTxtAfterEachAttr;
	
	while(1) //parse all attr and its val
	{
		if( ((text[0]=='/') && (text[1]=='>')) || (text[0]=='>'))
		{
			return err;
		}
		if( (*text=='\n') || (*text=='\t') || (*text==' ') ) //eat up white space.
		{
			text++;
			continue;
		}
		text = parseEachAttrNameVal(text,nd);
		if(text==NULL)
		{
			err = DUP_ATTR_NAME_ERR;
			return err;
		}
	}
}

char* parseTagname(char* text,Node* nd)
{
	int idx=0;
	text++;
	while(1)
	{
		if( (text[0] =='\n') || (text[0] =='\t') || (text[0] ==' ') || (text[0] =='>') ||
		    ( (text[0] =='/') && (text[1] =='>') )
		  )
		{
			return text;
		}
		else
		{
			nd->tagName[idx] = text[0];
			idx++;
			text++;
		}
	}
}

void initNode(Node* new_node)
{
	memset(new_node->tagName,0,MAX_NAME_LEN);
	memset(new_node->tagValue,0,MAX_NAME_LEN);
	new_node->attribList=NULL;
	new_node->sameLavelSibling=NULL;
	new_node->motherNode=NULL;
	new_node->childFirst=NULL;
	
}

void openTagFunc() //DONE
{
	Node *tmp;
	Node *nd;
	//printf("----------\n");
	//printf("openTagFunc = %s\n",yytext);
	tmp = (Node*)malloc(sizeof(Node));
	initNode(tmp);
	parseTagname(yytext,tmp);
	if(topNode==NULL)
	{
		topNode = tmp;
	}
	else
	{
		if(stackTop <= 0)
		{
			gblErrorFlag = MORE_THAN_ONE_TOP_NODE;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, "More than one top node:");
			strcat(errorFlagPrevContext,yytext);
			return ;
		}
		nd = nodeStack[stackTop-1];
		if(nd==NULL)
		{
			gblErrorFlag = GEN_ERROR;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, yytext);
			return ;
		}

		if(nd->childFirst == NULL)
		{
			nd->childFirst = tmp;
		}
		else
		{
			prevCloseTag->sameLavelSibling = tmp;
		}
		tmp->motherNode = nd;
	}
	nodeStack[stackTop] = tmp;
	stackTop++;
}

void openTagWidCloseTagFunc() //DONE
{
	Node *tmp;
	Node *nd;
	//printf("----------\n");
	//printf("openTagWidCloseTagFunc = %s\n",yytext);
	tmp = (Node*)malloc(sizeof(Node));
	initNode(tmp);
	parseTagname(yytext,tmp);
	if(topNode==NULL)
	{
		topNode = tmp;
	}
	else
	{
		if(stackTop <= 0)
		{
			gblErrorFlag = MORE_THAN_ONE_TOP_NODE;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, "More than one top node:");
			strcat(errorFlagPrevContext,yytext);
			return ;
		}
		nd = nodeStack[stackTop-1];
		if(nd==NULL)
		{
			gblErrorFlag = GEN_ERROR;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, yytext);
			return ;
		}
		if(nd->childFirst == NULL)
		{
			nd->childFirst = tmp;
		}
		else
		{
			prevCloseTag->sameLavelSibling = tmp;
		}
		tmp->motherNode = nd;
	}
	prevCloseTag = tmp;
}

void openTagWidAttrFunc()
{
	int err;
	char *txtAfterTagName;
	Node *tmp;
	Node *nd;
	//printf("----------\n");
	//printf("openTagWidAttrFunc = %s\n",yytext);
	tmp = (Node*)malloc(sizeof(Node));
	initNode(tmp);
	txtAfterTagName = parseTagname(yytext,tmp);
	err = parseAllAttr(txtAfterTagName,tmp);
	gblErrorFlag = err;
	if(topNode==NULL)
	{
		topNode = tmp;
	}
	else
	{
		if(stackTop <= 0)
		{
			gblErrorFlag = MORE_THAN_ONE_TOP_NODE;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, "More than one top node:");
			strcat(errorFlagPrevContext,yytext);
			return ;
		}
		nd = nodeStack[stackTop-1];
		if(nd==NULL)
		{
			gblErrorFlag = GEN_ERROR;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, yytext);
			return ;
		}
		if(nd->childFirst == NULL)
		{
			nd->childFirst = tmp;
		}
		else
		{
			prevCloseTag->sameLavelSibling = tmp;
		}
		tmp->motherNode = nd;
	}
	nodeStack[stackTop] = tmp;
	stackTop++;
}

void openTagWidCloseTagWidAttrFunc()
{
	//printf("----------\n");
	//printf("openTagWidCloseTagWidAttrFunc = %s\n",yytext);
	int err;
	char *txtAfterTagName;
	Node *tmp;
	Node *nd;
	tmp = (Node*)malloc(sizeof(Node));
	initNode(tmp);
	txtAfterTagName = parseTagname(yytext,tmp);
	err = parseAllAttr(txtAfterTagName,tmp);
	gblErrorFlag = err;
	if(topNode==NULL)
	{
		topNode = tmp;
	}
	else
	{
		if(stackTop <= 0)
		{
			gblErrorFlag = MORE_THAN_ONE_TOP_NODE;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, "More than one top node:");
			strcat(errorFlagPrevContext,yytext);
			return ;
		}
		nd = nodeStack[stackTop-1];
		if(nd==NULL)
		{
			gblErrorFlag = GEN_ERROR;
			errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
			strcpy(errorFlagPrevContext, yytext);
			return ;
		}
		if(nd->childFirst == NULL)
		{
			nd->childFirst = tmp;
		}
		else
		{
			prevCloseTag->sameLavelSibling = tmp;
		}
		tmp->motherNode = nd;
	}
	prevCloseTag = tmp;
}

void  tagValueFunc()
{
	//printf("----------\n");
	//printf("tagValueFunc = %s\n",yytext);
	Node* nd;
	if(stackTop <= 0)
	{
		gblErrorFlag = GEN_ERROR;
		errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
		strcpy(errorFlagPrevContext,yytext);
		return ;
	}
	nd = nodeStack[stackTop-1];
	if(nd==NULL)
	{
		gblErrorFlag = GEN_ERROR;
		errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
		strcpy(errorFlagPrevContext, yytext);
		return ;
	}
	strncpy(nd->tagValue,yytext,yyleng);
}

void closeTagFunc()
{
	//printf("----------\n");
	//printf("closeTagFunc = %s\n",yytext);
	Node *nd;
	char tagName[MAX_NAME_LEN];
	char *text;
	int idx,err;
	
	if(stackTop <= 0)
	{
		gblErrorFlag = GEN_ERROR;
		errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
		strcpy(errorFlagPrevContext, yytext);
		return ;
	}

	idx=0;
	err = NO_ERROR;
	memset(tagName,0,MAX_NAME_LEN);
	text = yytext;
	text++; //omit '<'
	text++; //omit '/'
	
	while(1)
	{
		if( (text[0] =='\n') || (text[0] =='\t') || (text[0] ==' ') || (text[0] =='>') )
			break;
		else
		{
			tagName[idx] = text[0];
			text++;
			idx++;
		}
	}
	nd = nodeStack[stackTop-1];
	if(nd==NULL)
	{
		gblErrorFlag = GEN_ERROR;
		errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
		strcpy(errorFlagPrevContext, yytext);
		return ;
	}
	err = strcmp(nd->tagName, tagName);
	if( err != 0 ) //tagname not matched.So nesting problem found.
	{
		errorFlagPrevContext = (char*)malloc(MAX_NAME_LEN*4);
		strcpy(errorFlagPrevContext, "Not matching close tag");
		strcat(errorFlagPrevContext,  tagName);
		gblErrorFlag = NODE_NESTING_ERR;
		printf("%s",errorFlagPrevContext);
		return ;
	}
	
	//prevCloseTag = nodeStack[stackTop-1];
	prevCloseTag = nd;
	nodeStack[stackTop-1] = NULL;
	stackTop--;
}

void errorFunc()
{
	printf("ERROR = %s\n",yytext);
	gblErrorFlag = GEN_ERROR;
	//yyterminate();
}

void showParsedXml(Node *nd) //probably have some error in this function
//void showParsedXml(int alignment)
{
	Node *tmp;
	Attribute* tempAttr;
	int flag=0;
	if(nd == NULL)
	{
		return ;
	}
	printf("<%s",nd->tagName);
	if( ((nd->tagValue[0]!=0) && (nd->tagValue!="")) || (nd->childFirst!=NULL) )
	{
		flag=1;
	}
	tempAttr = nd->attribList;
	while(tempAttr!=NULL)
	{
		printf(" %s=",tempAttr->attribName);
		if( (tempAttr->attribValue[0]!=0) || (tempAttr->attribValue!="") )
		{
			printf("'%s' ",tempAttr->attribValue);
		}
		else
		{
			printf("'' ");
		}
		tempAttr = tempAttr->nextAttrib;
	}
	if(flag==1)
	{
		printf(">");
	}
	else
	{
		printf("/>");
		return ;
	}
	if( (nd->tagValue[0]!=0) && (nd->tagValue!="") )
	{
		printf("%s",nd->tagValue);
		//printf("%s\n",nd->tagValue);
	}
	if(nd->childFirst != NULL)
	{
		tmp = nd->childFirst;
		while(tmp!=NULL)
		{
			showParsedXml(tmp);
			tmp= tmp->sameLavelSibling;
		}
		printf("</%s>",nd->tagName);
	}
}

void freeNodes(Node *nd)
{
	Attribute *attr;
	Attribute *tempattr ;
	Node *tmp;
	if(nd==NULL)
	{
		return;
	}
	else
	{
		attr = nd->attribList;
		while(attr != NULL) //free all attributes
		{
			tempattr = attr;
			attr = attr->nextAttrib;
			free(tempattr);
		}
		
		if(nd->childFirst != NULL) //now free child nodes recursively
		{
			tmp = nd->childFirst;
			while(tmp!=NULL)
			{
				freeNodes(tmp);
				tmp= tmp->sameLavelSibling;
			}
		}
		free(nd); ///free self
	}
}


int yywrap(void) {
    return 1;
}

int main(int argc, char *argv[]) 
{
	//memset(nextPossibleState, 0, sizeof(nextPossibleState));
	memset(nodeStack, 0, sizeof(nodeStack));
	//nextPossibleState[0] = 1;
	yyin = fopen(argv[1], "r");
	yylex();
	fclose(yyin);
	printf("\n\n\n");
	showParsedXml(topNode);
	
}
