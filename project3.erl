%%Advanced Functional Programming Project
%%made by Li Hao at 2013-4-22
-module(project3).
-export([initial/3, initialCell/1, manager/3, makeRandom/2]).

%%the loop function for each cell
cell(Status, Xpos, Ypos, NeighbourList, NumAliveNeighbours)->
	receive
		{notifyNeighbours}->
			%%when each cell receives this message, they will notify their neighbours their status
			lists:map(fun(X)->X!{myStatus, Status} end, NeighbourList),
			cell(Status, Xpos, Ypos, NeighbourList, NumAliveNeighbours);
		{processNextStep} ->
			%%when each cell receives this message, they will decide their next status according to how many alive neighbours they have.
			case (NumAliveNeighbours<2) or (NumAliveNeighbours>3) of
				true->
					frame!{change_cell, Xpos, Ypos, white},
					cell(dead, Xpos, Ypos, NeighbourList, 0);
				_ ->
					case (NumAliveNeighbours==3) and (Status==dead) of
						true->
							frame!{change_cell, Xpos, Ypos, purple},
							cell(alive, Xpos, Ypos, NeighbourList, 0);
						_ ->
							case Status==alive of
								true->
									frame!{change_cell, Xpos, Ypos, purple};
								_ ->
									frame!{change_cell, Xpos, Ypos, white}
							end,
							cell(Status, Xpos, Ypos, NeighbourList, 0)
					end
			end;
		{myStatus, OthersStatus}->
			%%when each cell receives this message, they will be notified one neighbour`s status.
			case OthersStatus==alive of
				true->
					cell(Status, Xpos, Ypos, NeighbourList, NumAliveNeighbours+1);
				_ ->
					cell(Status, Xpos, Ypos, NeighbourList, NumAliveNeighbours)
			end
	end.

%%the initial status of a cell waiting for receiving the pid list of its neighbours and location
initialCell(Status)->
	receive
		{startRunning, NeighbourList, Xpos, Ypos}->
			cell(Status, Xpos, Ypos, NeighbourList, 0)
	end.

createNode(IntX)->
	case IntX==88 of
		true->
			spawn(project3, initialCell, [alive]);
		_ ->
			spawn(project3, initialCell, [dead])
	end.


%%this function is used to transfer the cell number to its Pid
takeNthElements([], CellPidList)->[];
takeNthElements([Num|Nums], CellPidList)->
	[lists:nth(Num, CellPidList)]++takeNthElements(Nums, CellPidList).

%%startCell function is used to calculate one cell`s neighbours according to its location
startCell([], CellPidList, Xpos, Xmax, Ypos, Ymax) -> ok;
startCell(CellList, CellPidList, Xpos, Xmax, Ypos, Ymax) when Ypos>Ymax -> ok;
startCell(CellList, CellPidList, Xpos, Xmax, Ypos, Ymax) when Xpos>Xmax ->
	startCell(CellList, CellPidList, 1, Xmax, Ypos+1, Ymax);
startCell([Cell|OtherCells], CellPidList, Xpos, Xmax, Ypos, Ymax) when Xpos=<Xmax->
	Offsets=[-1,0,1],
	PossibleNeighbours=[{(Xpos+Offsetx), (Ypos+Offsety)} || Offsetx<-Offsets, Offsety<-Offsets, ((Offsetx=/=0) or (Offsety=/=0))],
	PossibleNeighbours2=lists:filter(fun({Xpos, Ypos})->(Xpos>0) and (Xpos=<Xmax) and (Ypos>0) and (Ypos=<Ymax) end, PossibleNeighbours),
	NeighboursNumber=lists:map(fun({X,Y})->(Y-1)*Xmax+X end, PossibleNeighbours2),
	NeighboursPid=takeNthElements(NeighboursNumber, CellPidList),
	Cell!{startRunning, NeighboursPid, Xpos, Ypos},
	startCell(OtherCells, CellPidList, Xpos+1, Xmax, Ypos, Ymax).

%%manager function is used to control the game notifying each cell
manager(Xmax, Ymax, CellPidList)->
	receive
		after 500->
				lists:map(fun(Pid)->Pid!{notifyNeighbours} end, CellPidList)
		end,
	receive
		after 1000->
				lists:map(fun(Pid)->Pid!{processNextStep} end, CellPidList)
		end,
	manager(Xmax, Ymax, CellPidList).

initial(Xmax, Ymax, Initial_string)->
	case whereis(frame)==undefined of
		true->
			io:format("the system is not ready yet ~n");
		_ ->
			continue
	end,
	InitialString=lists:flatten(Initial_string),
	CellPidList=lists:map(fun(X)->createNode(X) end, InitialString),
	startCell(CellPidList, CellPidList, 1, Xmax, 1, Ymax),
	frame!{set_w, Xmax+1},
	frame!{set_h, Ymax+1},
	register(manager, spawn(project3, manager, [Xmax, Ymax, CellPidList])).

%%the following functions are only for testing
make(X,Max,Total) when X>Max->
    [Total];
make(X,Max,Total) ->case random:uniform(20)==1 of
			true->
			    make(X+1,Max,lists:append(Total,"X"));
			_ ->
			    make(X+1,Max,lists:append(Total," "))
		    end.

%%makeRandom function is used to generate a random initial string
makeRandom(Xmax,Ymax)->
    make(1,Xmax*Ymax,[]).
