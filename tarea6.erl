% Lucia Cantú-Miller A01194199
% Paola Villarreal A00821971
% Alan Zavala A01338448

-module(tarea6).
-m([lists,math,io]).
-export([abre_tienda/0, tienda/0, suscribir_socio/1, socio/1, registra_producto/2, elimina_producto/1, modifica_producto/2, producto/1]).

% nombre corto del servidor (nombre@máquina)
nodo(Nombre) -> list_to_atom(atom_to_list(Nombre)++"@DESKTOP-2JRT0KR"). %CAMBIAR A NOMBRE DE TU MAQUINA

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
	        end;
        {De, {elimina_producto, Nombre_Producto}} ->
            case busca(Nombre_Producto, Lista_Productos) of
                inexistente ->
                    De ! inexistente;
                {C, Epid} ->
                    Epid ! {eliminar, Nombre_Producto},
                    De ! eliminado
            end,
            tienda(N, Lista_Socios, Lista_Productos);
        {De, {modifica_producto, Nombre_Producto, Cantidad}} ->
            case busca(Nombre_Producto, Lista_Productos) of
                inexistente ->
                    De ! inexistente;
                {C, Epid} ->
                    case C + Cantidad > 0 of
                        true ->
                            Epid ! {modificado, Nombre_Producto},
                            De ! modificado;
                        false ->
                            De ! excede
                    end
            end,
            tienda(N, Lista_Socios, Lista_Productos)
    end.

% CÓDIGO PARA LOS SOCIOS

socio(N) ->
   receive %estos mensajes no funciona, solo se pusieron por de mientras
      {mensaje, morir} ->
	     io:format("El esclavo ~w ha muerto~n", [N]);
      {mensaje, M} ->
	     io:format("El esclavo ~w recibió el mensaje ~w~n",
		           [N, M]),
	     socio(N)
   end.

% CÓDIGO PARA LOS PRODUCTOS

producto(N) ->
   receive
        {eliminar, Producto} ->
	        io:format("El producto ~s ha sido eliminado~n", [Producto]);
        {modificado, Producto} ->
            io:format("El producto ~s ha sido modificado~n", [Producto])
   end.

% FUNCIONES AUXILIARES

% busca un nombre dentro de la lista de productos
busca(_, []) -> inexistente;
busca(N, [{N, C, PID}|_]) -> {C, PID}; % regresa cantidad y PID
busca(N, [_|Resto]) -> busca(N, Resto).

% FUNCIONES DE INTERFAZ DE USUARIO

% crea y registra el proceso de la tienda con el alias "tienda"
abre_tienda() ->
    register(tienda, spawn(tarea6, tienda, [])),
    'tienda abierta'.

% suscribe socios creando procesos en el nodo "socios"
suscribir_socio(Socio) ->
    {tienda, nodo(tienda)} ! {suscribir_socio, Socio},
    ok.

% registra productos creando procesos en el nodo "productos"
registra_producto(Producto, Cantidad) ->
    {tienda, nodo(tienda)} ! {registra_producto, Producto, Cantidad},
    ok.

% elimina productos deteniendo el proceso correspondiente, si existe, en el nodo "productos"
elimina_producto(Producto) -> 
    {tienda, nodo(tienda)} ! {self(), {elimina_producto, Producto}},
    receive 
      inexistente -> 
	     io:format("El producto ~s no existe~n", [Producto]);
	  eliminado ->
	     {Producto}
   end.

% modifica la cantidad de los productos si existe y si es posible
modifica_producto(Producto, Cantidad) -> 
    {tienda, nodo(tienda)} ! {self(), {modifica_producto, Producto, Cantidad}},
    receive 
        inexistente -> 
	        io:format("El producto ~s no existe~n", [Producto]);
	    modificado ->
	        {Producto};
        excede ->
            io:format("El producto ~s no pudo ser modificado debido a que la cantidad excede las existencias~n", [Producto])
   end.





