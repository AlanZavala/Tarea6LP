% Lucia Cantú-Miller A01194199
% Paola Villarreal A00821971
% Alan Zavala A01338448

-module(tarea6).
-m([lists,math,io]).
-export([abre_tienda/0, suscribir_socio/1, tienda/0]).

% CÓDIGO PARA LA TIENDA

tienda() ->
    process_flag(trap_exit, true),
    tienda(1, []).
tienda(N, Lista_Socios) ->
    receive
        {suscribir_socio, Socio} ->
            Nodo = nodo(socios),
            monitor_node(Nodo, true),
            %Pid = spawn(Nodo, tarea6, socio, [N]),  
            receive
		        {nodedown, Nodo} -> 
                    io:format("nodo ~w no existe~n", [socios]),
                    tienda(N, Lista_Socios)
			    after 0 -> 
                    case lists:member(Socio, Lista_Socios) of
                        false ->
                            io:format("socio ~s creado ~n", [Socio]),
                            monitor_node(Nodo, false),
                            tienda(N+1, Lista_Socios++[Socio]);
                        true -> 
                            io:format("el socio ~s ya existe ~n", [Socio]),
                            tienda(N, Lista_Socios)
                    end
	        end
    end.

% nombre corto del servidor (nombre@máquina)
nodo(Nombre) -> list_to_atom(atom_to_list(Nombre)++"@DESKTOP-2JRT0KR").

% CÓDIGO PARA LOS SOCIOS


% FUNCIONES DE INTERFAZ DE USUARIO

% crea y registra el proceso de la tienda con el alias "tienda"
abre_tienda() ->
    register(tienda, spawn(tarea6, tienda, [])),
    'tienda abierta'.

suscribir_socio(Socio) ->
    {tienda, nodo(tienda)} ! {suscribir_socio, Socio},
    ok.




