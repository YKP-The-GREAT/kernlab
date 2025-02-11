## Spectral clustering
## author : alexandros
df = data.frame(matrix("", ncol = 7, nrow = 10))  

setGeneric("specc",function(x, ...) standardGeneric("specc"))
setMethod("specc", signature(x = "formula"),
          function(x, data = NULL, na.action = na.omit, ...)
          {
            mt <- terms(x, data = data)
            if(attr(mt, "response") > 0) stop("response not allowed in formula")
            attr(mt, "intercept") <- 0
            cl <- match.call()
            mf <- match.call(expand.dots = FALSE)
            mf$formula <- mf$x
            mf$... <- NULL
            mf[[1L]] <- quote(stats::model.frame)
            mf <- eval(mf, parent.frame())
            na.act <- attr(mf, "na.action")
            x <- model.matrix(mt, mf)
            res <- specc(x, ...)
            
            cl[[1]] <- as.name("specc")
            if(!is.null(na.act)) 
              n.action(res) <- na.action
            
            
            return(res)
          })

setMethod("specc",signature(x="matrix"),function(x, centers, kernel = "rbfdot", kpar = "automatic", nystrom.red = FALSE, nystrom.sample = dim(x)[1]/6, iterations = 200, mod.sample =  0.75, na.action = na.omit, ...)
{
  x <- na.action(x)
  rown <- rownames(x)
  x <- as.matrix(x)
  m <- nrow(x)
  if (missing(centers))
    stop("centers must be a number or a matrix")
  if (length(centers) == 1) {
    nc <-  centers
    if (m < centers)
      stop("more cluster centers than data points.")
  }
  else
    nc <- dim(centers)[2]
  
  
  if(is.character(kpar)) {
    kpar <- match.arg(kpar,c("automatic","local"))
    
    if(kpar == "automatic")
    {
      if (nystrom.red == TRUE)
        sam <- sample(1:m, floor(mod.sample*nystrom.sample))
      else
        sam <- sample(1:m, floor(mod.sample*m))
      
      sx <- unique(x[sam,])
      ns <- dim(sx)[1]
      dota <- rowSums(sx*sx)/2
      ktmp <- crossprod(t(sx))
      for (i in 1:ns)
        ktmp[i,]<- 2*(-ktmp[i,] + dota + rep(dota[i], ns))
      
      
      ## fix numerical prob.
      ktmp[ktmp<0] <- 0
      ktmp <- sqrt(ktmp)
      
      kmax <- max(ktmp)
      kmin <- min(ktmp + diag(rep(Inf,dim(ktmp)[1])))
      kmea <- mean(ktmp)
      lsmin <- log2(kmin)
      lsmax <- log2(kmax)
      midmax <- min(c(2*kmea, kmax))
      midmin <- max(c(kmea/2,kmin))
      rtmp <- c(seq(midmin,0.9*kmea,0.05*kmea), seq(kmea,midmax,0.08*kmea))
      if ((lsmax - (Re(log2(midmax))+0.5)) < 0.5) step <- (lsmax - (Re(log2(midmax))+0.5))
      else step <- 0.5
      if (((Re(log2(midmin))-0.5)-lsmin) < 0.5 ) stepm <-  ((Re(log2(midmin))-0.5) - lsmin)
      else stepm <- 0.5
      
      tmpsig <- c(2^(seq(lsmin,(Re(log2(midmin))-0.5), stepm)), rtmp, 2^(seq(Re(log2(midmax))+0.5, lsmax,step)))
      diss <- matrix(rep(Inf,length(tmpsig)*nc),ncol=nc)
      
      #
      cat("\n res <- kmeans(yi, centers, iterations)")
      
      for (i in 1:length(tmpsig)){
        cat('\n[',i,']: ', i)
        ka <- exp((-(ktmp^2))/(2*(tmpsig[i]^2)))
        diag(ka) <- 0
        
        d <- 1/sqrt(rowSums(ka))
        
        if(!any(d==Inf) && !any(is.na(d))&& (max(d)[1]-min(d)[1] < 10^4))
        {
          #
          cat("\nA: res <- kmeans(yi, centers, iterations)")
          
          l <- d * ka %*% diag(d)
          # cat('\nl: ',l,'\n')
          write.table(l, file="kmeans_l_ip.csv", sep = ',', row.names = F, col.names = F)
          
          # cat('l <- d * ka %*% diag(d) \n l: ', l)
          xi <- eigen(l,symmetric=TRUE)$vectors[,1:nc]
          # cat(' xi <- eigen(l,symmetric=TRUE)$vectors[,1:nc] \n xi: ', xi)
          # cat('\nxi: ',xi,'\n')
          write.table(xi, file="kmeans_x_ip.csv", sep = ',', row.names = F, col.names = F)
          
          yi <- xi/sqrt(rowSums(xi^2))
          # cat('yi <- xi/sqrt(rowSums(xi^2)) \n yi: ', yi)
          # cat('\n res <- kmeans(',yi,',',centers,',',iterations,')')
          # cat(typeof(yi),'\n')
          # cat(class(yi),'\n')
          # cat(dim(yi),'\n')
          # cat('\ny[',i,']: ', yi[,1],'\n')
          # cat('\ny[',i,']: ', yi[,2],'\n')
          write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
          
          
          
          # write.csv(yi,file="kmeans_ip.csv")
          
          
          
          
          
          res <- kmeans(yi, centers, iterations)
          # cat('\n res: ', res)
          # cat('\n diss[',i,'] <- ',res$withinss)
          # cat('\n',diss[i,] ,'<-', res$withinss)
          diss[i,] <- res$withinss
          # cat('\n diss[i,]: ', diss[i,])
        }
        
        # else
        # {
        #   # cat('\ny[',i,']: ', yi)
        #   # cat('\ny[',i,']: ', yi)
        #   # cat(typeof(yi),'\n')
        #   # cat(class(yi),'\n')
        #   # cat(dim(yi),'\n')
        # }
      }
      
      
      ms <- which.min(rowSums(diss))
      kernel <- rbfdot((tmpsig[ms]^(-2))/2)
      
      ## Compute Affinity Matrix
      if (nystrom.red == FALSE)
        km <- kernelMatrix(kernel, x)
    }
    if (kpar=="local")
    {
      if (nystrom.red == TRUE)
        stop ("Local Scaling not supported for nystrom reduction.")
      s <- rep(0,m)
      dota <- rowSums(x*x)/2
      dis <- crossprod(t(x))
      for (i in 1:m)
        dis[i,]<- 2*(-dis[i,] + dota + rep(dota[i],m))
      
      ## fix numerical prob.
      dis[dis < 0] <- 0
      
      for (i in 1:m)
        s[i] <- median(sort(sqrt(dis[i,]))[1:5])
      
      ## Compute Affinity Matrix
      km <- exp(-dis / s%*%t(s))
      kernel <- "Localy scaled RBF kernel"
      
      
    }
  }
  else 
  {
    if(!is(kernel,"kernel"))
    {
      if(is(kernel,"function")) kernel <- deparse(substitute(kernel))
      kernel <- do.call(kernel, kpar)
    }
    if(!is(kernel,"kernel")) stop("kernel must inherit from class `kernel'")
    
    ## Compute Affinity Matrix
    if (nystrom.red == FALSE)
      km <- kernelMatrix(kernel, x)
  }
  
  
  
  if (nystrom.red == TRUE){
    
    n <- floor(nystrom.sample)
    ind <- sample(1:m, m)
    x <- x[ind,]
    
    tmps <- sort(ind, index.return = TRUE)
    reind <- tmps$ix
    A <- kernelMatrix(kernel, x[1:n,])
    B <- kernelMatrix(kernel, x[-(1:n),], x[1:n,])
    d1 <- colSums(rbind(A,B))
    d2 <- rowSums(B) + drop(matrix(colSums(B),1) %*% .ginv(A)%*%t(B))
    dhat <- sqrt(1/c(d1,d2))
    
    A <- A * (dhat[1:n] %*% t(dhat[1:n]))
    B <- B * (dhat[(n+1):m] %*% t(dhat[1:n]))
    
    Asi <- .sqrtm(.ginv(A))
    Q <- A + Asi %*% crossprod(B) %*% Asi
    tmpres <- svd(Q)
    U <- tmpres$u
    L <- tmpres$d
    V <- rbind(A,B) %*% Asi %*% U %*% .ginv(sqrt(diag(L)))
    yi <- matrix(0,m,nc)
    # cat(' yi <- matrix(0,m,nc) \n: ', yi)
    ## for(i in 2:(nc +1))
    ##   yi[,i-1] <- V[,i]/V[,1]
    
    cat('\nres <- kmeans(yi[reind,], centers, iterations)')
    # cat('\nfor(i in 1:nc) ## specc
      # yi[,i] <- V[,i]/sqrt(sum(V[,i]^2)) \n yi: ', yi)
    for(i in 1:nc) ## specc
      yi[,i] <- V[,i]/sqrt(sum(V[,i]^2))
    # cat('\nyi[reind,]: ', yi[reind,])
    # cat('\nres <- kmeans(',yi[reind,],',', centers,',', iterations,')')
    cat('\nB: res <- kmeans(yi[reind,], centers, iterations)')
    # cat('\ny[',i,']: ', yi)
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n') 
    # cat('\nyi: ',yi,'\n')
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    res <- kmeans(yi[reind,], centers, iterations)
    # cat('\n res: ',res)s
    
  }
  else{
    if(is(kernel)[1] == "rbfkernel")
      diag(km) <- 0
    
    d <- 1/sqrt(rowSums(km))
    # cat('\nd <- 1/sqrt(rowSums(km)) \n d: ', d)

    l <- d * km %*% diag(d)
    # cat('\nl <- d * km %*% diag(d) \n l: ', l)
    # cat('\nl: ',l,'\n')
    write.table(l, file="kmeans_l_ip.csv", sep = ',', row.names = F, col.names = F)
    
    xi <- eigen(l)$vectors[,1:nc]
    # cat('\nxi <- eigen(l)$vectors[,1:nc] \n xi: ', xi)
    # cat('\nxi: ',xi,'\n')
    write.table(xi, file="kmeans_x_ip.csv", sep = ',', row.names = F, col.names = F)
    
    yi <- xi/sqrt(rowSums(xi^2))
    # cat('\nyi <- xi/sqrt(rowSums(xi^2)) \n yi: ', yi)
    cat('\nC: res <- kmeans(yi, centers, iterations)')
    # cat('\ny[',i,']: ', yi[,1])
    # cat('\ny[',i,']: ', yi[,2])
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n')
    # kmeans_ip=as.data.frame(yi)
    # cat('\nyi: ',yi,'\n')
    # cat('\nyi: ',yi,'\n')
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    
    res <- kmeans(yi, centers, iterations)
  }
  
  cent <- matrix(unlist(lapply(1:nc,ll<- function(l){colMeans(x[which(res$cluster==l), ,drop=FALSE])})),ncol=dim(x)[2], byrow=TRUE)
  
  withss <- unlist(lapply(1:nc,ll<- function(l){sum((x[which(res$cluster==l),, drop=FALSE] - cent[l,])^2)}))
  names(res$cluster) <- rown
  return(new("specc", .Data=res$cluster, size = res$size, centers=cent, withinss=withss, kernelf= kernel))
  
})

setMethod("specc",signature(x="list"),function(x, centers, kernel = "stringdot", kpar = list(length=4, lambda=0.5), nystrom.red = FALSE, nystrom.sample = length(x)/6, iterations = 200, mod.sample =  0.75, na.action = na.omit, ...)
{ 
  x <- na.action(x)
  m <- length(x)
  if (missing(centers))
    stop("centers must be a number or a matrix")
  if (length(centers) == 1) {
    nc <-  centers
    if (m < centers)
      stop("more cluster centers than data points.")
  }
  else
    nc <- dim(centers)[2]
  
  
  if(!is(kernel,"kernel"))
  {
    if(is(kernel,"function")) kernel <- deparse(substitute(kernel))
    kernel <- do.call(kernel, kpar)
  }
  if(!is(kernel,"kernel")) stop("kernel must inherit from class `kernel'")
  
  
  if (nystrom.red == TRUE){
    
    n <- nystrom.sample
    ind <- sample(1:m, m)
    x <- x[ind,]
    
    tmps <- sort(ind, index.return = TRUE)
    reind <- tmps$ix
    A <- kernelMatrix(kernel, x[1:n,])
    B <- kernelMatrix(kernel, x[-(1:n),], x[1:n,])
    d1 <- colSums(rbind(A,B))
    d2 <- rowSums(B) + drop(matrix(colSums(B),1) %*% .ginv(A)%*%t(B))
    dhat <- sqrt(1/c(d1,d2))
    
    A <- A * (dhat[1:n] %*% t(dhat[1:n]))
    B <- B * (dhat[(n+1):m] %*% t(dhat[1:n]))
    
    Asi <- .sqrtm(.ginv(A))
    Q <- A + Asi %*% crossprod(B) %*% Asi
    tmpres <- svd(Q)
    U <- tmpres$u
    L <- tmpres$d
    V <- rbind(A,B) %*% Asi %*% U %*% .ginv(sqrt(diag(L)))
    yi <- matrix(0,m,nc)
    
    ##    for(i in 2:(nc +1))
    ##      yi[,i-1] <- V[,i]/V[,1]
    
    for(i in 1:nc) ## specc
      yi[,i] <- V[,i]/sqrt(sum(V[,i]^2))
    
    # cat('\n for(i in 1:nc) ## specc 
    #     yi[,i] <- V[,i]/sqrt(sum(V[,i]^2)) \n yi: ', yi)
    # cat('\nyi[reind,]: ', yi[reind,])
    cat('\nD: res <- kmeans(yi[reind,], centers, iterations)')
    # cat('\ny[',i,']: ', yi[reind,],'\n')
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n')
    
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    
    res <- kmeans(yi[reind,], centers, iterations)
    
  }
  else{
    ## Compute Affinity Matrix / in our case just the kernel matrix 
    km <- kernelMatrix(kernel, x)
    
    if(is(kernel)[1] == "rbfkernel")
      diag(km) <- 0
    
    d <- 1/sqrt(rowSums(km))
    # cat('\nd <- 1/sqrt(rowSums(km)) \n d: ', d)
    l <- d * km %*% diag(d)
    # cat('\nl: ',l,'\n')
    write.table(l, file="kmeans_l_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat('\nl <- d * km %*% diag(d), l: ', l)
    xi <- eigen(l)$vectors[,1:nc]
    # cat('\nxi: ',xi,'\n')
    write.table(xi, file="kmeans_x_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat('\nxi <- eigen(l)$vectors[,1:nc] \n: ', xi)
    sqxi <- rowSums(xi^2)
    if(any(sqxi==0)) stop("Zero eigenvector elements, try using a lower value for the length hyper-parameter")
    yi <- xi/sqrt(sqxi)
    # cat('\nyi <- xi/sqrt(sqxi) \n yi: ',yi)
    cat('\nE: res <- kmeans(yi, centers, iterations)')
    # cat('\ny[',i,']: ', yi,'\n')
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n')
    res <- kmeans(yi, centers, iterations)
  }
  
  return(new("specc", .Data=res$cluster, size = res$size, kernelf= kernel))
  
})


setMethod("specc",signature(x="kernelMatrix"),function(x, centers, nystrom.red = FALSE,  iterations = 200, ...)
{
  m <- nrow(x)
  if (missing(centers))
    stop("centers must be a number or a matrix")
  if (length(centers) == 1) {
    nc <-  centers
    if (m < centers)
      stop("more cluster centers than data points.")
  }
  else
    nc <- dim(centers)[2]
  
  if(dim(x)[1]!=dim(x)[2])
  {
    nystrom.red <- TRUE
    if(dim(x)[1] < dim(x)[2])
      x <- t(x)
    m <- nrow(x)
    n <- ncol(x)
  }
  
  if (nystrom.red == TRUE){
    
    A <- x[1:n,]
    B <- x[-(1:n),]
    d1 <- colSums(rbind(A,B))
    d2 <- rowSums(B) + drop(matrix(colSums(B),1) %*% .ginv(A)%*%t(B))
    dhat <- sqrt(1/c(d1,d2))
    
    A <- A * (dhat[1:n] %*% t(dhat[1:n]))
    B <- B * (dhat[(n+1):m] %*% t(dhat[1:n]))
    
    Asi <- .sqrtm(.ginv(A))
    Q <- A + Asi %*% crossprod(B) %*% Asi
    tmpres <- svd(Q)
    U <- tmpres$u
    L <- tmpres$d
    
    V <- rbind(A,B) %*% Asi %*% U %*% .ginv(sqrt(diag(L)))
    yi <- matrix(0,m,nc)
    
    ## for(i in 2:(nc +1))
    ##   yi[,i-1] <- V[,i]/V[,1]
    
    for(i in 1:nc) ## specc
      yi[,i] <- V[,i]/sqrt(sum(V[,i]^2))
    # cat(' \nfor(i in 1:nc) ## specc
    #   yi[,i] <- V[,i]/sqrt(sum(V[,i]^2)) \n yi: ', yi)
    cat('\nF: res <- kmeans(yi, centers, iterations)')
    # cat('\ny[',i,']: ', yi)
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n')
    res <- kmeans(yi, centers, iterations)
    
  }
  else{
    
    d <- 1/sqrt(rowSums(x))
    # cat('\nd <- 1/sqrt(rowSums(x)) \n d: ', d)
    l <- d * x %*% diag(d)
    # cat('\nl: ',l,'\n')
    write.table(l, file="kmeans_l_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat('\nl <- d * x %*% diag(d) \n l: ', l)
    xi <- eigen(l)$vectors[,1:nc]
    # cat('\nxi: ',xi,'\n')
    write.table(xi, file="kmeans_x_ip.csv", sep = ',', row.names = F, col.names = F)
    
    # cat('\nxi <- eigen(l)$vectors[,1:nc] \n xi: ', xi)
    yi <- xi/sqrt(rowSums(xi^2))
    # cat('\nyi <- xi/sqrt(rowSums(xi^2)) \n yi:', yi)
    
    cat('\nG: res <- kmeans(yi, centers, iterations)')
    # cat('\ny[',i,']: ', yi)
    
    write.table(yi, file="kmeans_ip.csv", sep = ',', row.names = F, col.names = F)
    # 
    # cat(typeof(yi),'\n')
    # cat(class(yi),'\n')
    # cat(dim(yi),'\n')
    res <- kmeans(yi, centers, iterations)
  }
  
  ## cent <- matrix(unlist(lapply(1:nc,ll<- function(l){colMeans(x[which(res$cluster==l),])})),ncol=dim(x)[2], byrow=TRUE)
  
  ##  withss <- unlist(lapply(1:nc,ll<- function(l){sum((x[which(res$cluster==l),] - cent[l,])^2)}))
  
  return(new("specc", .Data=res$cluster, size = res$size, centers = matrix(0), withinss = c(0), kernelf= "Kernel Matrix used as input."))
  
})


setMethod("show","specc",
          function(object){
            
            cat("Spectral Clustering object of class \"specc\"","\n")
            cat("\n","Cluster memberships:","\n","\n")
            cat(object@.Data,"\n","\n")
            show(kernelf(object))
            cat("\n")
            if(!any(is.na(centers(object)))){
              cat(paste("Centers: ","\n"))
              show(centers(object))
              cat("\n")}
            cat(paste("Cluster size: ","\n"))
            show(size(object))
            cat("\n")
            if(!is.logical(withinss(object))){
              cat(paste("Within-cluster sum of squares: ", "\n"))
              show(withinss(object))
              cat("\n")}
          })


.ginv <- function (X, tol = sqrt(.Machine$double.eps))
{
  if (length(dim(X)) > 2 || !(is.numeric(X) || is.complex(X)))
    stop("'X' must be a numeric or complex matrix")
  if (!is.matrix(X))
    X <- as.matrix(X)
  Xsvd <- svd(X)
  if (is.complex(X))
    Xsvd$u <- Conj(Xsvd$u)
  Positive <- Xsvd$d > max(tol * Xsvd$d[1], 0)
  if (all(Positive))
    Xsvd$v %*% (1/Xsvd$d * t(Xsvd$u))
  else if (!any(Positive))
    array(0, dim(X)[2:1])
  else Xsvd$v[, Positive, drop = FALSE] %*% ((1/Xsvd$d[Positive]) * t(Xsvd$u[, Positive, drop = FALSE]))
}

.sqrtm <- function(x)
{
  tmpres <- eigen(x)
  V <- t(tmpres$vectors)
  D <- tmpres$values
  if(is.complex(D))
    D <- Re(D)
  D <- pmax(D,0)
  return(crossprod(V*sqrt(D),V))
}

