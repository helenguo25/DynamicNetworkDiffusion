function simplifiedSpreadingModel = simplifiedSpreadingModel(numHosts,numSteps,...
    infectionStep,freezeStep,criteria,...
   coreCriteria,randomSeed1,randomSeed2,outputPrefix, ...
    num_neighbors, num_neighbors_keep, activeedgeProb)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Last Updated: 09/08/2018 to include adjacency file  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%function simplifiedParasiteModel(numHosts,numSteps,...
%    infectionStep,freezeStep,criteria,...
%    parasiteReproductionProb,effectivenessOfGrooming,...
%    spreadProb,randomSeed1,randomSeed2,outputPrefix)
% Inputs:
%   - numHosts: The number of individuals in the population
%   - numSteps: The total number of steps in the simulation
%   - infectionStep: The iteration to begin the random infection
%   - freezeStep: The iteration to FREEZE the dynamic network. 
%   - criteria: Which centrality measure to select edges based on
%               0 = Random, 1 = Degree, 2 = Closeness, 3 = Betweenness
%   - parasiteReproductionProb: 
%       parasitesNext = parasitesCurrent*parasiteReproductionProb
%   - effectivenessOfGroomingProb:
%       parasitesGroomed = parasitesCurrent*(1-q)^N;
%   - spreadProb
%        parasitesSpreadToGroomee = s; 
%   - coreCriteria:
%        0 = infect the periphery (i.e., the non KEEP of the network).
%        1 = infect the core (i.e., the top KEEP of the network.)
%   - randomSeed1: randomSeed for the network dynamics
%   - randomSeed2: randomSeed for the parasite dynamics
%   - outputPrefix: The prefix for all the output files.
%
% Outputs:
%   Note: All output files will begin with "outputPrefix_"
%   - command.txt: Inputs + RandomSeeds;
%   - node.txt:    All Centrality Measures, Plus Parasite Load;
%   - network.txt: All Centrality Measures, Plus Parasite Burden; 
%   - edge.txt:    Core->Core, Core->Per, Per->Core, Per->Per

% Note: This edge.txt plot will track the amount of parasites that
%       travel on each edge (not sure how I can check this)
%       For now we will leave this part blank.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Goal: Simulate a number of hosts evolving according to the           %
%       degree model. Do the indidence of parasites cause differences  %
%       in the underlying social structure?                            %
%                                                                      %                                                        
% Comments:                                                            %
% (1) Betweenness/Closeness are computed on the undirected graphs      %
%     We added a "copy" of edges as an undirected graph!               %
% (2) We are doing a different version of betweenness/closeness than   %
%     Nina or Matlab (2017). At some point we may want to consider a   %
%     different type of structure.                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%close all;
%clear;
warning('off','all')
addpath('./MIT_Code')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BEGIN PARAMETERS FOR THE MODEL TO MODIFY %
%    Change/Modify Values Here to Test     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Number of Hosts
NUM_HOSTS             = numHosts;

%Number of Neighbors (Outgoing Edges)
NUM_NEIGHBORS         = num_neighbors;

%Number of Neighbors to Keep/Drop
NUM_NEIGHBORS_KEEP    = num_neighbors_keep;
NUM_NEIGHBORS_DROP    = NUM_NEIGHBORS-NUM_NEIGHBORS_KEEP;

%Criteria to Maximize:
% 0 == Random;
% 1 == Degree
% 2 == Closeness;
% 3 == Betweenness; 
CRITERIA = criteria;

if(~(CRITERIA==0 || CRITERIA==1 || CRITERIA == 2 || CRITERIA == 3))
    error('Criteria must be set to a valid choice: 0,1,2 or 3');
end

CORECRITERIA = coreCriteria;
if(~(CORECRITERIA==0 || CORECRITERIA==1 || CORECRITERIA==2))
    error('Core Criteria must be set to a valid choice: 0,1 or 2');
end

%Number of iterations (Steps) in the model
NUM_STEPS         = numSteps;

%Where Infection Begins in the model;
INFECTION_STEP    = infectionStep;

%The Step at which we will FREEZE the network dynamics
FREEZE_STEP       = freezeStep;

%If set to 1 will initialize with a cycle
DEBUG = 0;

%Seed/Set-up the randomStreams
%We want separate randomStreams for paraistes and nodes to decouple
%completey the dynamics/repeat if needed;
seedNetwork  = RandStream('mt19937ar','Seed',randomSeed1);
seedINFECTION = RandStream('mt19937ar','Seed',randomSeed2);

%Create Output File for Debuggind
debugFile = sprintf('%s_debug.txt',outputPrefix);
debugOut = fopen(debugFile,'w');

%Create Output Files:
docFile = sprintf('%s_command.txt',outputPrefix);
docOut  = fopen(docFile,'w');

adjFile = sprintf('%s_adjacency.txt',outputPrefix);
adjOut  = fopen(adjFile,'w');

activeFile = sprintf('%s_active.txt',outputPrefix);
activeOut  = fopen(activeFile,'w');

nodeDegreeFile = sprintf('%s_nodeDegree.txt',outputPrefix);
nodeDegreeOut  = fopen(nodeDegreeFile,'w');

nodeClosenessFile = sprintf('%s_nodeCloseness.txt',outputPrefix);
nodeClosenessOut  = fopen(nodeClosenessFile,'w');

nodeBetweennessFile = sprintf('%s_nodeBetweenness.txt',outputPrefix);
nodeBetweennessOut  = fopen(nodeBetweennessFile,'w');

nodeInfectionFile = sprintf('%s_nodeInfection.txt',outputPrefix);
nodeInfectionOut  = fopen(nodeInfectionFile,'w');

graphFile = sprintf('%s_graph.txt',outputPrefix);
graphOut  = fopen(graphFile,'w');


%Print the Command to the OutputFile:
fprintf(docOut,'%s\n',date);
fprintf(docOut, 'function simplifiedSpreadingModel(numHosts,numSteps,infectionStep,freezestep,criteria,coreCriteria,randomSeed1,randomSeed2,outputPrefix)\n');
fprintf(docOut, 'function simplifiedSpreadingModel(%i,%i,%i,%i,%i,%i,%i,%i,%s)\n',numHosts,numSteps,infectionStep,freezeStep,criteria,coreCriteria,randomSeed1,randomSeed2,outputPrefix);
fprintf(docOut, '\n');

fprintf(docOut, 'Graph File: Iterate, Betweenness, Closeness, Degree.\n');
fprintf(docOut, 'Node File : One file for each metric; Iterate, Node1(Metric), Node2(Metric). etc.\n');
fclose(docOut);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% END PARAMETERS FOR THE MODEL TO MODIFY %
%    Do not change values below here!    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Step -1: Parasite Parameters %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

INITIAL_INFECTION         = zeros(NUM_HOSTS,1); %individuals/node
INITIAL_NUMBER_INFECTED       = 0;

%Binomial Distribution Probabilities
p                             = activeedgeProb;

%Error Check:
if(p<0)
    error('Must have activeedgeProb >= 0');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%
% Step 0: Initial Set-Up %
%%%%%%%%%%%%%%%%%%%%%%%%%%

connected = 0;
numTrials = 1;
MAX_TRIALS = 10;

INITIAL_EDGES            = zeros(NUM_HOSTS,NUM_HOSTS);
INITIAL_UNDIRECTED_EDGES = zeros(NUM_HOSTS,NUM_HOSTS);

while ( connected == 0 && numTrials < MAX_TRIALS)

    %(a)Set up the directed edges;
    %Edges are from node i to node j
    if(DEBUG == 1)
        %Complete Graph
        %INITIAL_EDGES = ones(NUM_HOSTS,NUM_HOSTS);
        %INITIAL_EDGES = INITIAL_EDGES - eye(NUM_HOSTS);
        
        %Cycle:
        for i=1:(NUM_HOSTS-1)
            INITIAL_EDGES(i,i+1) = 1;
            INITIAL_UNDIRECTED_EDGES(i,i+1) = 1;
            INITIAL_UNDIRECTED_EDGES(i+1,i) = 1;
        end
        INITIAL_EDGES(NUM_HOSTS,1) = 1;
        INITIAL_UNDIRECTED_EDGES(NUM_HOSTS,1) = 1;
        INITIAL_UNDIRECTED_EDGES(1,NUM_HOSTS) = 1;
        
        %IMPORTANT TEST CASE: Parallel vertex did not have the same
        %                     betweenness.
        %INITIAL_EDGES(1,2) = 1; INITIAL_EDGES(2,3) = 1;
        %INITIAL_EDGES(3,4) = 1;
        %INITIAL_EDGES(4,5) = 1;
        %INITIAL_EDGES(5,1) = 1;
        %INITIAL_EDGES(1,6) = 1; INITIAL_EDGES(6,3) = 1;      
    else 
        for i = 1:NUM_HOSTS
            NEIGHBORS = randperm(seedNetwork,NUM_HOSTS-1,NUM_NEIGHBORS);
            for j = 1:length(NEIGHBORS)
                if(NEIGHBORS(j)<i)
                    INITIAL_EDGES(i,NEIGHBORS(j)) = 1;
                    INITIAL_UNDIRECTED_EDGES(i,NEIGHBORS(j)) = 1;
                    INITIAL_UNDIRECTED_EDGES(NEIGHBORS(j),i) = 1;
                else
                    INITIAL_EDGES(i,NEIGHBORS(j)+1) = 1;
                    INITIAL_UNDIRECTED_EDGES(i,NEIGHBORS(j)+1) = 1;
                    INITIAL_UNDIRECTED_EDGES(NEIGHBORS(j)+1,i) = 1;
                end
            end
        end
    end
    
    %(b) Check to make sure connected
    connected = mbiIsConnected(INITIAL_UNDIRECTED_EDGES);
    numTrials = numTrials+1;
end

if(numTrials>=MAX_TRIALS)
    error('Failed to Find a Connected Graph');
end

%Step (c): Compute Centrality Metrics

%Compute Node/Graph Degree (in/out)
[INITIAL_DEG, INITIAL_NODE_DEGREE,INITIAL_OUT_DEGREE] = degrees(INITIAL_EDGES);
INITIAL_GRAPH_DEGREE                                  = mbiGraphDegree(INITIAL_NODE_DEGREE);

%Compte Node/Graph Closeness
INITIAL_NODE_CLOSENESS  = mbiCloseness(INITIAL_UNDIRECTED_EDGES);
INITIAL_GRAPH_CLOSENESS = mbiGraphCloseness(INITIAL_NODE_CLOSENESS);

%Compute Node/Graph Betweenness
INITIAL_NODE_BETWEENNESS  = node_betweenness_faster(INITIAL_UNDIRECTED_EDGES);
INITIAL_GRAPH_BETWEENNESS = mbiGraphBetweenness(INITIAL_NODE_BETWEENNESS);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Step 1: Run the Host Model Iterations with All Metrics %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Store the Initial Computations on the Graph 
CURR_NODE_DEGREE          = INITIAL_NODE_DEGREE;
CURR_GRAPH_DEGREE         = INITIAL_GRAPH_DEGREE; 

CURR_NODE_CLOSENESS       = INITIAL_NODE_CLOSENESS;
CURR_GRAPH_CLOSENESS      = INITIAL_GRAPH_CLOSENESS;

CURR_NODE_BETWEENNESS     = INITIAL_NODE_BETWEENNESS;
CURR_GRAPH_BETWEENNESS    = INITIAL_GRAPH_BETWEENNESS;

CURRENT_EDGES             = INITIAL_EDGES;
CURRENT_UNDIRECTED_EDGES  = INITIAL_UNDIRECTED_EDGES;

%Store the Initial Computations on the Graph 
CURRENT_INFECTION     = INITIAL_INFECTION;
NEXT_INFECTION       = INITIAL_INFECTION;
PAST_INFECTION        = INITIAL_INFECTION;


%Begin the Iterations/Sampling;
%There are TWO phases to the iterations: 
%       Phase 1: Spreading; Phase 2: Network Resample
for iterate = 1:NUM_STEPS
    if mod(iterate,10) == 0
       iterate
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Phase 0: Store a Copy of the Current Configuration %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    NEXT_INFECTION    = CURRENT_INFECTION;
     ACTIVE_EDGES = zeros(NUM_HOSTS,NUM_NEIGHBORS);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Phase 1: SPREADING %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if (iterate>= INFECTION_STEP)
       infection_step = iterate;
       
       if(iterate == INFECTION_STEP)
           
           %RANDOM
           if(CRITERIA == 0)
               I         = randperm(seedINFECTION,NUM_HOSTS);
           %DEGREE
           elseif(CRITERIA == 1)
               [S,I]     = sort(CURR_NODE_DEGREE,'descend');
           %CLOSENESS
           elseif(CRITERIA == 2)
               [S,I]     = sort(CURR_NODE_CLOSENESS,'descend');
           %BETWEENNESS
           elseif(CRITERIA == 3)
               [S,I]     = sort(CURR_NODE_BETWEENNESS,'descend');
           end
           
           %(0) Periphery: Pick infection in the periphery
           if(CORECRITERIA == 0)
               patient0  = I(randi(seedINFECTION,[NUM_NEIGHBORS_KEEP+1,NUM_HOSTS]));
           %(1) Core: Pick infection in the core
           elseif(CORECRITERIA == 1)                 
               patient0  = I(randi(seedINFECTION,NUM_NEIGHBORS_KEEP));
           %(2) Random: Pick a Random host.
           elseif(CORECRITERIA == 2)
               patient0  = randi(seedINFECTION,NUM_HOSTS);
           end
           NEXT_INFECTION(patient0) = 1;
       else
           %Each individual updates their parasite load based on 
           % (1) reproduction on self.
           % (2) reductions of load by grooming + assignment of new
           %     infections to groomers
           
          
           PAST_INFECTION = CURRENT_INFECTION;
           
           %Spreading the infection
         
           for i = 1:NUM_HOSTS
           for j = 1:NUM_HOSTS
               counter = 0;
               if(CURRENT_EDGES(i,j)>0)
                  counter = counter+1;
                if(rand(seedINFECTION) < p)
                    ACTIVE_EDGES(i,counter)=1;
                    if (CURRENT_INFECTION(i)==1)
                        NEXT_INFECTION(j)=1;
                    end
                end
               end
           end
           end
       end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Phase 2: Network Resampling %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    nextConnected = 0;
    numTrials = 1;
    MAX_TRIALS = 10;

    while ( nextConnected == 0 && numTrials < MAX_TRIALS)
        NEXT_EDGES            = CURRENT_EDGES;
        NEXT_UNDIRECTED_EDGES = CURRENT_UNDIRECTED_EDGES;
        
        if(iterate>=FREEZE_STEP)
            %Do nothing we have frozen the network resampling.
            freeze_iterate = iterate;
            freeze_iterate;
        else
        
            for i = 1:NUM_HOSTS
                %RANDOM
                if(CRITERIA == 0)
                    [S,I] = sort(CURRENT_EDGES(i,:).*rand(seedNetwork,1,NUM_HOSTS),'descend');
                %DEGREE
                elseif(CRITERIA == 1)
                    [S,I] = sort(CURRENT_EDGES(i,:).*CURR_NODE_DEGREE,'descend');
                %CLOSENESS
                elseif(CRITERIA == 2)
                    eps = .1;
                    [S,I] = sort(CURRENT_EDGES(i,:).*(CURR_NODE_CLOSENESS+eps*ones(size(CURR_NODE_CLOSENESS)) )','descend');
                    %[S,I] = sort(CURRENT_EDGES(i,:).*(CURR_NODE_CLOSENESS)','descend');

                %BETWEENNESS
                elseif(CRITERIA == 3)
                    eps = .1;
                    [S,I] = sort(CURRENT_EDGES(i,:).*(CURR_NODE_BETWEENNESS+eps*ones(size(CURR_NODE_BETWEENNESS)) ),'descend');
                    %[S,I] = sort(CURRENT_EDGES(i,:).*(CURR_NODE_BETWEENNESS),'descend');

                else
                    CRITERIA
                    exit('Should not be here. Invalid criteria value.'); 
                end
                                
                %SortNodes by Degree: 3 Categories
                %NUM_NEIGHBORS_KEEP = 3;
                %NUM_NEIGHBORS = 5;
                keepNodes   = I(1:NUM_NEIGHBORS_KEEP);
                deleteNodes = I(NUM_NEIGHBORS_KEEP+1:NUM_NEIGHBORS);
                sampleNodes = I(NUM_NEIGHBORS+1:NUM_HOSTS);
                
                %Delete the host itself so we do not get self edges.
                sampleNodes(sampleNodes==i)=[];
               
                %Determine New Neighbors:
                newIndex     = randperm(seedNetwork,length(sampleNodes),NUM_NEIGHBORS_DROP);
                newNeighbors = zeros(1,NUM_NEIGHBORS_DROP);
                for j = 1:NUM_NEIGHBORS_DROP
                    newNeighbors(j) = sampleNodes(newIndex(j));
                end

                %Drop Previous Neighbors and Add New Neighbors
                for j = 1:NUM_NEIGHBORS_DROP
                    if( NEXT_EDGES(i,deleteNodes(j)) == 1)
                        NEXT_EDGES(i,deleteNodes(j)) = 0;
                        NEXT_UNDIRECTED_EDGES(i,deleteNodes(j))  = 0;
                        NEXT_UNDIRECTED_EDGES(deleteNodes(j),i) = 0; 
                    else
                        deleteNodes(j)
                        exit('Error: Trying to Delete an Edge that is not there!');
                    end

                    if( NEXT_EDGES(i,newNeighbors(j)) == 0)
                        NEXT_EDGES(i,newNeighbors(j)) = 1;
                        NEXT_UNDIRECTED_EDGES(i,newNeighbors(j)) = 1;
                        NEXT_UNDIRECTED_EDGES(newNeighbors(j),i) = 1;
                    else
                        exit('Error: Trying to Add an Edge that already exists!');
                    end
                end        
            end
        end
        
        nextConnected = mbiIsConnected(NEXT_UNDIRECTED_EDGES);
%         if(nextConnected==0)
%             error('We disconnected the graph');
%         end
        numTrials = numTrials+1;

    end
    
    if(numTrials>3)
        numTrials
    end
    
    if(numTrials > MAX_TRIALS)
        exit('Error in Graph Iteration! Could not create connected graph w/in the maximum number of iterations!'); 
    end
 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Phase 3: Store Configuration and Recompute and Store Metrics %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
                CURRENT_EDGES = NEXT_EDGES;
    CURRENT_UNDIRECTED_EDGES = NEXT_UNDIRECTED_EDGES;
    CURRENT_INFECTION    = NEXT_INFECTION;
   
    %Compute Node/Graph Degree (in/out)
    %CURRENT_EDGES -> Directed Graphs
    [DEG, CURR_NODE_DEGREE,OUT_DEGREE] = degrees(CURRENT_EDGES);
    CURR_GRAPH_DEGREE                  = mbiGraphDegree(CURR_NODE_DEGREE);

    %for p=1:NUM_HOSTS
    %    if(CURRENT_EDGES(p,p) == 1)
    %        CURRENT_EDGES(p,p)
    %        iterate
    %    end
    %end
    
    if(max(CURR_NODE_DEGREE)>=50)
        CURR_NODE_DEGREE
        
        CURRENT_EDGES
        
    end
    %for p=1:length(OUT_DEGREE)
    %   if(OUT_DEGREE(p)!=5)
    %       OUT_DEGREE(p)
    %   end
    %end
    
    %Compte Node/Graph Closeness
    CURR_NODE_CLOSENESS  = mbiCloseness(CURRENT_UNDIRECTED_EDGES);
    CURR_GRAPH_CLOSENESS = mbiGraphCloseness(CURR_NODE_CLOSENESS);

    %Compute Node/Graph Betweenness
    %Commenting out Betweenness because it was causing problems!
    CURR_NODE_BETWEENNESS  = node_betweenness_faster(CURRENT_UNDIRECTED_EDGES);
    CURR_GRAPH_BETWEENNESS = mbiGraphBetweenness(CURR_NODE_BETWEENNESS);
    
    CURRENT_NUMBER_INFECTED = sum(CURRENT_INFECTION);
    
    %%%%%%%%%%%%%%%%
    % Print Output %
    %%%%%%%%%%%%%%%%

    %Print Graph Information:
    fprintf(graphOut,'%i',iterate);
    fprintf(graphOut,' %.10f %.10f %.10f',CURR_GRAPH_BETWEENNESS,CURR_GRAPH_CLOSENESS,CURR_GRAPH_DEGREE);
    fprintf(graphOut,'\n');
    
    %Print Node Information:
    fprintf(nodeDegreeOut, '%i',iterate);
    fprintf(nodeClosenessOut, '%i',iterate);
    fprintf(nodeBetweennessOut,'%i',iterate);
    fprintf(adjOut, '%i', iterate);
    fprintf(activeOut, '%i', iterate);
    for i = 1:NUM_HOSTS
        fprintf(nodeDegreeOut, ' %i',CURR_NODE_DEGREE(i));
        fprintf(nodeClosenessOut, ' %.10f',CURR_NODE_CLOSENESS(i));
        fprintf(nodeBetweennessOut, ' %.10f',CURR_NODE_BETWEENNESS(i));
        fprintf(nodeInfectionOut,' %.10f',CURRENT_INFECTION(i));
        fprintf(adjOut,' %s',vec2str(find(CURRENT_EDGES(i,:)),[],[],0));
        fprintf(activeOut,' %s',vec2str(ACTIVE_EDGES(i,:),[],[],0));
    end
    fprintf(nodeDegreeOut,'\n');
    fprintf(nodeClosenessOut, '\n');
    fprintf(nodeBetweennessOut, '\n'); 
    fprintf(nodeInfectionOut,'\n');
    fprintf(adjOut,'\n');
     fprintf(activeOut,'\n');
end
end
%%%%%%%%%%%%%%%%%%%%%%
% Close Output Files %
%%%%%%%%%%%%%%%%%%%%%%

fclose(nodeDegreeOut);
fclose(nodeClosenessOut);
fclose(nodeBetweennessOut);
fclose(nodeInfectionOut);
fclose(graphOut);
fclose(adjOut);
fclose(activeOut);
end

