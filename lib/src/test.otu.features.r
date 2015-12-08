# response: dependent variable
# treatment: treatment variable to compare
# control: variables to control for
# treatment.interaction.var: variable that we're interested in testing interaction with treatment with
# RETURNS a dataframe of non adjusted pvalues, adjusted pvalues, and summaries (list of dataframes if more than one coefficient of interest)
test.otu.features<-function(otu, map, response="taxa", treatment, controls, treatment.interaction.var=NULL, use.corr=F, p.adjust.factor=NA)
{
	library(Hmisc)
	if(is.null(treatment.interaction.var)) #if no interaction term
	{
		if(treatment %in% colnames(map) && is.factor(map[,treatment])){
			coefficient.vars <- paste(treatment, levels(map[,treatment])[2], sep="")
		} else {
			coefficient.vars <- treatment
		}
		f.str <- paste(response, paste0(c(treatment, controls), collapse=" + "), sep=" ~ ")
		vars <- c(response, treatment, controls)
		vars <- vars[vars!="taxa"] #remove "taxa" since this is always found when looping through the otu table
		dependent <- vars[!(vars %in% controls)]
	} else { #if interaction term exists
		# for factors, make sure to append value to interaction term
		treatment.interaction <- paste(treatment.interaction.var, levels(map[,treatment.interaction.var])[2], sep="")
		# let's grab info for the interaction as well as the clinical variable
		coefficient.vars <- c(paste(treatment, treatment.interaction, sep=":"), treatment.interaction)
		f.str <- paste(response, " ~ ", treatment, "*", treatment.interaction.var, " + ", paste0(controls, collapse=" + "), sep="")
		vars <- c(response, treatment, controls, treatment.interaction.var)
		vars <- vars[vars!="taxa"] #remove "taxa" since this is always found when looping through the otu table
	}
		
	f <- as.formula(f.str)

	if(use.corr==T)
	{
		pvals <- apply(otu, 2, function(taxa) cor.test(x=taxa, y=map[,dependent], method="spearman", exact=F)$p.value)
		if(!is.na(p.adjust.factor)) {
			adj.pvals <- p.adjust(pvals, "fdr", n=length(pvals)*p.adjust.factor)
		} else {
			adj.pvals <- p.adjust(pvals, "fdr")
		}

		rhos <- apply(otu, 2, function(taxa) cor.test(x=taxa, y=map[,dependent], method="spearman", exact=F)$estimate)
		return(data.frame(adj.pvals=adj.pvals,coeffs=rhos))
	}
	else
	{
print(vars)
		summaries <- apply(otu, 2, function(taxa) summary(lm(f, data.frame(taxa=taxa, map[,vars]))))
		ret <- list()
		for(i in 1:length(coefficient.vars))
		{
			summaries_coefficients <- sapply(summaries, function(x) { c <- coefficients(x);
														if(length(which(rownames(c) == coefficient.vars[i])) != 0){c[coefficient.vars[i],]}else{rep(NA,4)}})

			if(nrow(summaries_coefficients) != 0) {
				rownames(summaries_coefficients) <- c("Estimate","Std. Error","t value","Pr(>|z|)")
				pvals <- summaries_coefficients["Pr(>|z|)",]
				if(!is.na(p.adjust.factor)) {
					adj.pvals <- p.adjust(pvals, "fdr", n=length(pvals)*p.adjust.factor)
				} else {
					adj.pvals <- p.adjust(pvals, "fdr")
				}
				ret[[coefficient.vars[i]]] <- data.frame(pvals=pvals, adj.pvals=adj.pvals, coeffs=summaries_coefficients["Estimate",])	
			} else {
				# if nothing comes back just return an empty coefficient box 
				ret[[coefficient.vars[i]]] <- data.frame(pvals=NA, adj.pvals=NA, coeffs=NA)	
			}
		}

		return(ret)
	}
}
