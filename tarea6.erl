% Lucia Cantú-Miller A01194199
% Paola Villarreal A00821971
% Alan Zavala A01338448

-module(tarea6).
-m([lists,math,io]).
-export([abre_tienda/0, suscribir_socio/1, tienda/0, socio/1, registra_producto/2, producto/1]).

% CÓDIGO PARA LA TIENDA

tienda() ->
    process_flag(trap_exit, true),
    tienda(1, [], []).
tienda(N, Lista_Socios, Lista_Productos) ->
    receive
        {suscribir_socio, Nombre_Socio} ->
            Nodo = nodo(socios),
            monitor_node(Nodo, true), 
            receive
		        {nodedown, Nodo} -> 
                    io:format("nodo ~w no existe~n", [socios]),
                    tienda(N, Lista_Socios, Lista_Productos)
			    after 0 -> 
                    case lists:keyfind(Nombre_Socio, 1, Lista_Socios) of
                        false ->
                            Sid = spawn(Nodo, tarea6, socio, [N]), 
                            io:format("socio ~s creado ~n", [Nombre_Socio]),
                            monitor_node(Nodo, false),
                            tienda(N+1, Lista_Socios++[{Nombre_Socio, Sid}], Lista_Productos);
                        {Nombre_Socio, _} -> 
                            io:format("el socio ~s ya existe ~n", [Nombre_Socio]),
                            tienda(N, Lista_Socios, Lista_Productos)
                    end
	        end;
        {registra_producto, Nombre_Producto, Cantidad} ->
            Nodo = nodo(productos),
            monitor_node(Nodo, true),
            Pid = spawn(Nodo, tarea6, producto, [N]),
            receive
		        {nodedown, Nodo} -> 
                    io:format("nodo ~w no existe~n", [socios]),
                    tienda(N, Lista_Socios, Lista_Productos)
			    after 0 -> 
                    io:format("producto ~s creado ~n", [Nombre_Producto]),
                    monitor_node(Nodo, false),
                    tienda(N, Lista_Socios, Lista_Productos++[{Nombre_Producto, Cantidad, Pid}])
	        end 
    end.

% nombre corto del servidor (nombre@máquina)
nodo(Nombre) -> list_to_atom(atom_to_list(Nombre)++"@DESKTOP-2JRT0KR").

% CÓDIGO PARA LOS SOCIOS

socio(N) ->
   receive
      {mensaje, morir} ->
	     io:format("El esclavo ~w ha muerto~n", [N]);
      {mensaje, M} ->
	     io:format("El esclavo ~w recibió el mensaje ~w~n",
		           [N, M]),
	     socio(N)
   end.

producto(N) ->
   receive
      {mensaje, morir} ->
	     io:format("El esclavo ~w ha muerto~n", [N]);
      {mensaje, M} ->
	     io:format("El esclavo ~w recibió el mensaje ~w~n",
		           [N, M]),
	     socio(N)
   end.

% FUNCIONES DE INTERFAZ DE USUARIO

% crea y registra el proceso de la tienda con el alias "tienda"
abre_tienda() ->
    register(tienda, spawn(tarea6, tienda, [])),
    'tienda abierta'.

suscribir_socio(Socio) ->
    {tienda, nodo(tienda)} ! {suscribir_socio, Socio},
    ok.

registra_producto(Producto, Cantidad) ->
    {tienda, nodo(tienda)} ! {registra_producto, Producto, Cantidad},
    ok.






